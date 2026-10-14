import Foundation
import XCTest
@testable import Nuvio

final class ExternalPlayerNuvioNativeTests: XCTestCase {
    func testDistinctNativePlayerSchemeAndEncodedHandoff() throws {
        XCTAssertTrue(ExternalPlayer.allCases.contains(.nuvioNative))
        XCTAssertEqual(ExternalPlayer.nuvioNative.probeScheme, "nuvio-player")
        XCTAssertTrue(ExternalPlayer.nuvioNative.acceptsSubtitleURL)
        let stream = "https://cdn.example/film.mkv?key=alpha%2Bbeta&expires=1"
        let url = try XCTUnwrap(ExternalPlayer.nuvioNative.playbackURL(
            for: stream, title: "Film & More",
            subtitleURL: "https://subs.example/en.srt?x=1&y=2"))
        XCTAssertEqual(url.scheme, "nuvio-player")
        XCTAssertEqual(url.host, "stream")
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "url" })?.value, stream)
        XCTAssertEqual(query.first(where: { $0.name == "title" })?.value, "Film & More")
        XCTAssertEqual(query.first(where: { $0.name == "sub" })?.value, "https://subs.example/en.srt?x=1&y=2")
    }
}
