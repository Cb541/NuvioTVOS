import XCTest
@testable import Nuvio

/// Reported: "Keeps adding Cinemeta and Open Subtitles addons even after removing them in Nuvio,
/// it also re-enables them if disabled."
///
/// Two separate causes, both here. The addon list lived only in `addons.json`, which carries the
/// manifests and therefore sits in the purgeable cache — so when tvOS reclaimed it, `init` found
/// nothing and seeded the two defaults over whatever the viewer had chosen. And `syncAddons`
/// pulled the account's list before pushing the local one, so a removal was reinstalled a moment
/// before the push that would have carried it.
@MainActor
final class AddonPersistenceTests: XCTestCase {
    /// Where the purgeable half lives, so a test can do to it what the system does.
    private var manifestCacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Nuvio", isDirectory: true)
            .appendingPathComponent("addons.json")
    }

    /// The stores share one container, so a test that assumed the list it found would be the
    /// list it left behind would depend on which test ran before it.
    private func emptyStore() -> AddonStore {
        let store = AddonStore()
        for record in store.installed { store.uninstall(baseUrl: record.baseUrl) }
        store.clearPendingAddonRemovals(store.pendingAddonRemovals)
        return store
    }

    /// These tests empty a store that the whole process — and the UI suite, which launches the
    /// app against the same container — shares. Put the defaults back, or the next thing to ask
    /// for a catalog finds no addon able to serve one.
    override func tearDown() {
        let store = AddonStore()
        for record in store.installed { store.uninstall(baseUrl: record.baseUrl) }
        for url in AddonStore.defaultAddonURLs {
            store.adoptForTesting(baseUrl: url, enabled: true)
        }
        store.clearPendingAddonRemovals(store.pendingAddonRemovals)
        super.tearDown()
    }

    /// The reported regression, reproduced the way the system produces it.
    func testAPurgedManifestCacheDoesNotBringTheDefaultsBack() throws {
        let first = emptyStore()
        XCTAssertTrue(first.installed.isEmpty)

        // What tvOS does to the Caches directory whenever it feels like it.
        if let url = manifestCacheURL, FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let second = AddonStore()
        XCTAssertTrue(
            second.installed.isEmpty,
            "a purged manifest cache must not reinstate the defaults over the viewer's list"
        )
        second.clearPendingAddonRemovals(second.pendingAddonRemovals)
    }

    /// A disabled addon has to survive the same purge, for the same reason.
    func testADisabledAddonSurvivesAPurgedManifestCache() throws {
        let first = emptyStore()
        let url = AddonStore.defaultAddonURLs[0]
        first.adoptForTesting(baseUrl: url, enabled: true)
        first.setEnabled(false, baseUrl: url)

        if let cache = manifestCacheURL, FileManager.default.fileExists(atPath: cache.path) {
            try FileManager.default.removeItem(at: cache)
        }

        let second = AddonStore()
        XCTAssertEqual(second.installed.first?.baseUrl, StremioURL.canonicalize(url))
        XCTAssertEqual(second.installed.first?.enabled, false)
    }

    // MARK: The removal queue

    func testUninstallingQueuesTheRemovalForTheAccount() {
        let store = emptyStore()
        let url = AddonStore.defaultAddonURLs[0]
        store.adoptForTesting(baseUrl: url, enabled: true)
        store.uninstall(baseUrl: url)

        XCTAssertTrue(store.hasPendingRemoval(url))
        XCTAssertTrue(store.hasPendingRemoval(url.uppercased()), "the check is case-insensitive")
    }

    func testAnAcknowledgedRemovalLeavesTheQueue() {
        let store = emptyStore()
        let url = AddonStore.defaultAddonURLs[0]
        store.adoptForTesting(baseUrl: url, enabled: true)
        store.uninstall(baseUrl: url)
        store.clearPendingAddonRemovals(store.pendingAddonRemovals)

        XCTAssertFalse(store.hasPendingRemoval(url))
    }

    func testRemovingSomethingTwiceQueuesItOnce() {
        let store = emptyStore()
        let url = AddonStore.defaultAddonURLs[0]
        store.adoptForTesting(baseUrl: url, enabled: true)
        store.uninstall(baseUrl: url)
        store.uninstall(baseUrl: url)

        XCTAssertEqual(store.pendingAddonRemovals.count, 1)
    }
}
