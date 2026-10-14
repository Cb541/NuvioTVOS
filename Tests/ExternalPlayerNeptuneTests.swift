import Foundation
import XCTest
@testable import Nuvio

/// The Neptune route is experimental until Neptune publishes a direct-stream URL contract.
final class ExternalPlayerNeptuneTests: XCTestCase {
    func testNeptuneAppearsAsAnExternalPlayer() {
        XCTAssertTrue(ExternalPlayer.allCases.contains(.neptune))
        XCTAssertEqual(ExternalPlayer.neptune.rawValue, "neptune")
        XCTAssertEqual(ExternalPlayer.neptune.probeScheme, "neptune")
        XCTAssertTrue(ExternalPlayer.neptune.displayName.contains("Experimental"))
        XCTAssertFalse(ExternalPlayer.neptune.acceptsSubtitleURL)
    }

    func testNeptuneDirectLinkEscapesSignedStreamAndTitle() throws {
        let signed = "https://cdn.example/media.mkv?token=one%2Btwo&expires=42"
        let url = try XCTUnwrap(ExternalPlayer.neptune.playbackURL(
            for: signed,
            title: "Movie & Episode",
            subtitleURL: "https://example.test/en.srt"
        ))
        XCTAssertEqual(url.scheme, "neptune")
        XCTAssertEqual(url.host, "play")
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "url" })?.value, signed)
        XCTAssertEqual(query.first(where: { $0.name == "title" })?.value, "Movie & Episode")
        // The Neptune deep-link format is not verified. Do not pretend to support subtitles.
        XCTAssertNil(query.first(where: { $0.name == "sub" }))
    }
}
