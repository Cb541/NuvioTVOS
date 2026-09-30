import Foundation

/// Whether anything installed could serve a stream for a title, so Play can answer before it
/// is pressed rather than after a round trip to an empty list.
struct PlaybackAvailability: Equatable {
    var addons: [Addon] = []
    /// Already filtered by the viewer's switches — `PluginStore.enabledScrapers`.
    var scrapers: [InstalledScraper] = []
    /// Until the addon manifests have reported, fail open rather than disabling playback.
    var isLoaded = false

    /// `video` is supplied for episodes because an addon may attach playable streams directly
    /// to the meta video instead of implementing `/stream`.
    func canStream(type: String, videoId: String, video: Video? = nil) -> Bool {
        guard isLoaded else { return true }

        if let video, video.id == videoId, video.hasEmbeddedStreams {
            return true
        }

        if addons.contains(where: {
            $0.enabled && $0.handles(id: videoId, resource: "stream", type: type)
        }) {
            return true
        }

        return scrapers.contains { $0.supports(type: type) }
    }
}
