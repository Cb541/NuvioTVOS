import Foundation
import XCTest
@testable import Nuvio

final class ExternalPlayerPlezyTests: XCTestCase {
    func testPlezyIsOfferedAsExternalPlayer() {
        XCTAssertTrue(ExternalPlayer.allCases.contains(.plezy))
        XCTAssertEqual(ExternalPlayer.plezy.displayName, "Plezy")
        XCTAssertEqual(ExternalPlayer.plezy.probeScheme, "plezy")
        XCTAssertTrue(ExternalPlayer.plezy.acceptsSubtitleURL)
    }

    func testDirectStreamHandoffPreservesSignedQueryAndSubtitle() throws {
        let signed = "https://cdn.example/movie.mkv?token=alpha%2Bbeta&expires=123"
        let link = try XCTUnwrap(ExternalPlayer.plezy.playbackURL(
            for: signed,
            title: "Movie & More",
            subtitleURL: "https://subs.example/en.srt?key=1&lang=en"
        ))
        XCTAssertEqual(link.scheme, "plezy")
        XCTAssertEqual(link.host, "stream")
        let items = try XCTUnwrap(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first(where: { $0.name == "url" })?.value, signed)
        XCTAssertEqual(items.first(where: { $0.name == "title" })?.value, "Movie & More")
        XCTAssertEqual(
            items.first(where: { $0.name == "sub" })?.value,
            "https://subs.example/en.srt?key=1&lang=en"
        )
    }

    func testHandoffWithoutSubtitleDoesNotAddOne() throws {
        let link = try XCTUnwrap(ExternalPlayer.plezy.playbackURL(
            for: "https://example.test/video.mkv",
            title: nil
        ))
        XCTAssertNil(URLComponents(url: link, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "sub" }))
    }
}
