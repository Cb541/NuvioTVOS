import XCTest

/// Reported: "Turning off layout > show labels breaks catalogs. As soon as the setting is turned
/// off I can only see my watchlist, all the catalogs are missing."
///
/// It was not the labels. Turning them off shrank the Home rows viewport by 152 points while the
/// row at the top of it — Continue Watching, whose cards carry their own title and progress line
/// and which that setting does not govern — stayed exactly as tall. The first row then filled the
/// viewport, the `LazyVStack` below had no room to realise the next one, and with nothing
/// realised there was nothing for focus to move to. The rails existed and could not be reached.
///
/// So the assertion is reachability, not presence: a query that only counted posters passed
/// while the screen was broken.
final class PosterLabelsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchHome(labels: Bool, backdropExpand: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-nuvioUITesting", "-startTab", "home", "-nuvioLibraryHarness",
            "-nuvioSetting", "layout.poster_labels_enabled=\(labels)",
            "-nuvioSetting", "layout.focused_poster_backdrop_expand_enabled=\(backdropExpand)"
        ]
        app.launch()
        return app
    }

    /// One predicate rather than an enumeration: `matching(…).count` over this tree is slow
    /// enough that polling it in a loop starved the rest of the UI suite of simulator time.
    private func focusedPoster(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'card.poster.' AND hasFocus == true")
        ).firstMatch
    }

    func testCatalogsStayReachableBelowContinueWatching() {
        // Both settings that shrink the rows viewport, in every combination: the report was
        // labels off, but the smaller allowance left by "expand to backdrop" off is the same
        // hazard and would have been the next report.
        for (labels, expand) in [(true, true), (false, true), (true, false), (false, false)] {
            let app = launchHome(labels: labels, backdropExpand: expand)
            let context = "labels=\(labels) expand=\(expand)"

            // Watch progress persists between launches, so the rail is asserted rather than
            // assumed — an early version of this test compared two different screens.
            let rail = app.buttons["card.continue.harness-resume"]
            XCTAssertTrue(
                rail.waitForExistence(timeout: 30), "\(context): the fixture rail should be up"
            )

            var reached = focusedPoster(in: app).exists
            for _ in 0..<6 where !reached {
                XCUIRemote.shared.press(.down)
                usleep(600_000)
                reached = focusedPoster(in: app).exists
            }

            XCTAssertTrue(
                reached, "\(context): a catalog poster below Continue Watching should be reachable"
            )
            app.terminate()
        }
    }
}
