import XCTest

/// Reported: "I'm not sure how to change any of the settings with a + and - sign, pressing the
/// center button does nothing and left/right move around the menus."
///
/// It was true of every stepper in the app. `SettingsStepperRow` handed its two buttons to
/// `SettingsRow` as a trailing accessory, and `SettingsRow` is a `Button` — on tvOS the contents
/// of a button's label are not focusable, so neither step button could ever take the remote.
/// Select landed on the row's own empty action.
///
/// Whether a nested control is reachable is a focus-engine question that exists only at runtime,
/// so it is asked here with a real remote rather than reasoned about — the same lesson the poster
/// long press taught in 1.0.32, where twenty policy tests passed while nothing could be pressed.
final class SettingsStepperUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-nuvioUITesting", "-startTab", "settings", "-settingsSection", "layout"
        ]
        app.launch()
    }

    private var stepperValues: [String] {
        app.staticTexts.matching(
            NSPredicate(format: "identifier BEGINSWITH 'settings.stepper.value.'")
        ).allElementsBoundByIndex.map(\.label)
    }

    func testAStepperCanBeFocusedAndPressed() {
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "identifier BEGINSWITH 'settings.stepper.value.'")
            ).element(boundBy: 0).waitForExistence(timeout: 30),
            "the Layout screen should be up"
        )
        let before = stepperValues
        XCTAssertFalse(before.isEmpty, "the Layout screen has three steppers")

        // Into the workspace, then down the card list. Nothing is assumed about where the
        // settings rail leaves focus at launch, and the Poster cards section is well down the
        // scroll, so this walks rather than guessing a count.
        XCUIRemote.shared.press(.right)
        usleep(600_000)

        // A vertical walk stays in the same column, so it lands on `minus`; `plus` is one press
        // to the right of it. Either proves the row is reachable.
        var reachedAStepButton = false
        for _ in 0..<40 {
            let steps = app.buttons.matching(identifier: "minus").allElementsBoundByIndex
                + app.buttons.matching(identifier: "plus").allElementsBoundByIndex
            if steps.contains(where: { $0.hasFocus }) {
                reachedAStepButton = true
                XCUIRemote.shared.press(.select)
                usleep(500_000)
                if stepperValues != before { break }
            }
            XCUIRemote.shared.press(.down)
            usleep(500_000)
        }

        XCTAssertTrue(
            reachedAStepButton,
            "a step button should be able to take focus — it never could when the row was a Button"
        )
        XCTAssertNotEqual(
            stepperValues, before,
            "pressing Select on a step button should change its value"
        )
    }
}
