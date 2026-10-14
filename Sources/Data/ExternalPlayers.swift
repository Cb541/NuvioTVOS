import Foundation
import UIKit

/// Third-party tvOS players Nuvio can hand a stream to.
///
/// This is the practical answer to AVFoundation's container coverage: Infuse, VLC and the others
/// bring their own demuxers, so an MKV that the system player refuses opens fine in them.
///
/// The trade-off is real and worth knowing: a hand-off carries only a URL. Per-stream request
/// headers cannot travel with it, so a debrid link that needs an `Authorization` or `Referer`
/// header will fail in an external player even though it plays internally. Nuvio says so at the
/// point of choice rather than letting it fail silently.
enum ExternalPlayer: String, CaseIterable, Identifiable, Codable, Sendable {
    case infuse
    case vlc
    case nplayer
    case senplayer
    case nativePlayer = "nativeplayer"
    case neptune
    case outplayer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .infuse: return "Infuse"
        case .vlc: return "VLC"
        case .nplayer: return "nPlayer"
        case .senplayer: return "SenPlayer"
        case .nativePlayer: return "Native Player"
        case .neptune: return "Neptune (Experimental)"
        case .outplayer: return "Outplayer"
        }
    }

    var summary: String {
        switch self {
        case .infuse: return "Broad container and codec support, Firecore"
        case .vlc: return "Plays essentially anything, VideoLAN"
        case .nplayer: return "Hardware-accelerated, wide format support"
        case .senplayer: return "Dolby Vision and wide-format external playback"
        case .nativePlayer: return "Native tvOS playback with TrueHD Atmos, DTS:X and Dolby Vision"
        case .neptune: return "Test Nuvio URL handoff; Neptune direct-stream support is unverified"
        case .outplayer: return "Lightweight MKV-capable player"
        }
    }

    /// Scheme probed with `canOpenURL`, and declared in `LSApplicationQueriesSchemes`.
    var probeScheme: String {
        switch self {
        case .infuse: return "infuse"
        case .vlc: return "vlc-x-callback"
        case .nplayer: return "nplayer"
        case .senplayer: return "senplayer"
        case .nativePlayer: return "nativeplayer"
        case .neptune: return "neptune"
        case .outplayer: return "outplayer"
        }
    }

    /// Whether this player accepts a sidecar subtitle URL on its callback. nPlayer and Outplayer
    /// take a bare stream URL and nothing else, so a track cannot travel with the hand-off.
    var acceptsSubtitleURL: Bool {
        switch self {
        case .infuse, .vlc, .nativePlayer: return true
        case .nplayer, .senplayer, .neptune, .outplayer: return false
        }
    }

    /// Builds the hand-off URL. Infuse and VLC take an x-callback-url with the stream as a query
    /// parameter; nPlayer and Outplayer concatenate the stream onto their scheme directly.
    ///
    /// `subtitleURL` is the addon track the viewer had selected, forwarded when
    /// `external_player_forward_subtitles` is on. Without it the hand-off silently drops the
    /// subtitles — the external player only sees the video URL and has no idea a track was chosen.
    func playbackURL(for stream: String, title: String?, subtitleURL: String? = nil) -> URL? {
        guard let encoded = stream.addingPercentEncoding(
            withAllowedCharacters: .externalPlayerArgument
        ) else { return nil }
        let encodedSubtitle = subtitleURL?.nilIfBlank?.addingPercentEncoding(
            withAllowedCharacters: .externalPlayerArgument
        )

        switch self {
        case .infuse:
            var string = "infuse://x-callback-url/play?url=\(encoded)"
            if let title, let encodedTitle = title.addingPercentEncoding(
                withAllowedCharacters: .externalPlayerArgument
            ) {
                string += "&name=\(encodedTitle)"
            }
            if let encodedSubtitle { string += "&sub=\(encodedSubtitle)" }
            return URL(string: string)
        case .vlc:
            var string = "vlc-x-callback://x-callback-url/stream?url=\(encoded)"
            if let encodedSubtitle { string += "&sub=\(encodedSubtitle)" }
            return URL(string: string)
        case .nplayer:
            // nPlayer takes the raw URL appended to its scheme, not percent-encoded.
            return URL(string: "nplayer-\(stream)")
        case .senplayer:
            // SenPlayer uses the x-callback-url handoff and expects the stream
            // as the percent-encoded `url` query parameter.
            return URL(string: "senplayer://x-callback-url/play?url=\(encoded)")
        case .neptune:
            // EXPERIMENTAL: Neptune has not published a verified direct-stream URI scheme.
            // Try a plausible URI ONLY as a capability test; recognition/playback is not guaranteed.
            var string = "neptune://play?url=\(encoded)"
            if let title, let encodedTitle = title.addingPercentEncoding(
                withAllowedCharacters: .externalPlayerArgument
            ) {
                string += "&title=\(encodedTitle)"
            }
            return URL(string: string)
        case .nativePlayer:
            // Native Player mirrors Infuse's x-callback handoff. Title and an optional
            // sidecar subtitle can travel with the resolved stream URL.
            var string = "nativeplayer://x-callback-url/play?url=\(encoded)"
            if let title, let encodedTitle = title.addingPercentEncoding(
                withAllowedCharacters: .externalPlayerArgument
            ) {
                string += "&name=\(encodedTitle)"
            }
            if let encodedSubtitle { string += "&sub=\(encodedSubtitle)" }
            return URL(string: string)
        case .outplayer:
            return URL(string: "outplayer://\(stream)")
        }
    }
}

extension CharacterSet {
    /// Everything that must survive as data inside a query parameter — notably `&`, `?` and `=`,
    /// which appear in debrid and CDN links and would otherwise split the callback URL.
    static let externalPlayerArgument: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}

@MainActor
enum ExternalPlayerLauncher {
    /// Detected installed players, plus explicit experimental launch probes.
    /// Neptune appears regardless of scheme detection so users can test unsupported handoffs.
    static var installed: [ExternalPlayer] {
        ExternalPlayer.allCases.filter { isInstalled($0) }
    }

    static func isInstalled(_ player: ExternalPlayer) -> Bool {
        // tvOS can report false for some custom URL schemes even when the app is installed.
        // SenPlayer and Native Player both have verified x-callback handoffs, so keep them
        // available in the external-player list.
        if player == .senplayer || player == .nativePlayer || player == .neptune {
            return true
        }

        guard let probe = URL(string: "\(player.probeScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(probe)
    }

    @discardableResult
    static func open(
        _ player: ExternalPlayer,
        stream: String,
        title: String?,
        subtitleURL: String? = nil
    ) -> Bool {
        guard let url = player.playbackURL(for: stream, title: title, subtitleURL: subtitleURL) else {
            return false
        }

        if player == .neptune {
            // Neither the URL scheme nor direct stream playback is documented by Neptune.
            // Probe both likely scheme names, with an explicit negative result when neither
            // is registered. Nuvio's picker keeps an error visible instead of disappearing.
            let urls: [URL] = [
                url,
                URL(string: url.absoluteString.replacingOccurrences(
                    of: "neptune://", with: "neptuneplayer://", range: url.absoluteString.startIndex..<url.absoluteString.endIndex
                ))
            ].compactMap { $0 }
            guard let supported = urls.first(where: { UIApplication.shared.canOpenURL($0) }) else {
                return false
            }
            UIApplication.shared.open(supported)
            return true
        }

        if player != .senplayer && player != .nativePlayer && !UIApplication.shared.canOpenURL(url) {
            return false
        }

        UIApplication.shared.open(url)
        return true
    }
}
