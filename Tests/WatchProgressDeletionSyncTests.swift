import XCTest
@testable import Nuvio

/// Removing a title from Continue Watching, and marking something unwatched, both delete a watch
/// progress row. Until 1.0.36 they deleted it locally only: the next account sync pulled the row
/// back, found no local counterpart, adopted it, and silently undid the viewer's action.
///
/// The saved library already had the fix — `pendingLibraryDeletions`, pushed before the pull —
/// and the comment above `syncLibrary` spells out exactly this hazard. Watch progress simply
/// never got it, and the poster-options dialog that performs both actions was itself unreachable
/// until 1.0.32, so nothing exercised the path.
@MainActor
final class WatchProgressDeletionSyncTests: XCTestCase {
    private func store() -> LibraryStore {
        let store = LibraryStore()
        // The store is file-backed and the suite shares one container, so start from a known
        // state rather than from whatever an earlier test left behind.
        store.clearPendingProgressDeletions(store.pendingProgressDeletions)
        for existing in store.progress.values { store.clearProgress(videoId: existing.videoId) }
        store.clearPendingProgressDeletions(store.pendingProgressDeletions)
        return store
    }

    private func record(_ store: LibraryStore, videoId: String, contentId: String = "tt1") {
        store.record(
            contentId: contentId, contentType: "movie", videoId: videoId,
            season: nil, episode: nil, position: 60, duration: 120, preview: nil
        )
    }

    func testRemovingFromContinueWatchingQueuesTheDeletion() {
        let store = store()
        record(store, videoId: "tt1")
        store.clearProgress(videoId: "tt1")

        XCTAssertEqual(store.pendingProgressDeletions, ["tt1"])
    }

    /// The regression this file exists for.
    func testAQueuedDeletionIsNotAdoptedBackFromTheAccount() {
        let store = store()
        record(store, videoId: "tt1")
        store.clearProgress(videoId: "tt1")

        store.adoptProgress(WatchProgress(
            contentId: "tt1", contentType: "movie", videoId: "tt1",
            season: nil, episode: nil, positionSeconds: 60, durationSeconds: 120, updatedAt: Date()
        ))

        XCTAssertNil(store.progress(forVideoId: "tt1"))
    }

    /// Once the account has taken the delete, the queue is empty and the row may arrive again —
    /// which is what watching it on another device looks like.
    func testAnAcknowledgedDeletionStopsBlockingAdoption() {
        let store = store()
        record(store, videoId: "tt1")
        store.clearProgress(videoId: "tt1")
        store.clearPendingProgressDeletions(["tt1"])

        store.adoptProgress(WatchProgress(
            contentId: "tt1", contentType: "movie", videoId: "tt1",
            season: nil, episode: nil, positionSeconds: 60, durationSeconds: 120, updatedAt: Date()
        ))

        XCTAssertNotNil(store.progress(forVideoId: "tt1"))
    }

    /// Watching it again outranks a removal that has not been pushed yet. Without this the row
    /// would be written locally and then deleted on the account by the very next sync.
    func testWatchingSomethingAgainCancelsItsPendingDeletion() {
        let store = store()
        record(store, videoId: "tt1")
        store.clearProgress(videoId: "tt1")
        record(store, videoId: "tt1")

        XCTAssertTrue(store.pendingProgressDeletions.isEmpty)
        XCTAssertNotNil(store.progress(forVideoId: "tt1"))
    }

    func testMarkingWatchedCancelsItsPendingDeletion() {
        let store = store()
        record(store, videoId: "tt1")
        store.clearProgress(videoId: "tt1")
        store.markWatched(
            contentId: "tt1", contentType: "movie", videoId: "tt1",
            season: nil, episode: nil, duration: 120
        )

        XCTAssertTrue(store.pendingProgressDeletions.isEmpty)
    }

    /// Marking a series unwatched clears every episode at once. All of them have to be queued,
    /// not just the first.
    func testClearingAWholeSeriesQueuesEveryEpisode() {
        let store = store()
        record(store, videoId: "tt9:1:1", contentId: "tt9")
        record(store, videoId: "tt9:1:2", contentId: "tt9")
        store.clearProgress(contentId: "tt9")

        XCTAssertEqual(store.pendingProgressDeletions.sorted(), ["tt9:1:1", "tt9:1:2"])
    }

    /// Clearing something that was never there is not a deletion to push.
    func testClearingAnAbsentRowQueuesNothing() {
        let store = store()
        store.clearProgress(videoId: "nothing")

        XCTAssertTrue(store.pendingProgressDeletions.isEmpty)
    }
}
