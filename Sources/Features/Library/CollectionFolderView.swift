import SwiftUI
import Observation

/// Loads a folder's sources, one page at a time, keeping each source's results apart so the
/// tabbed layout has something to put in tabs.
@Observable
@MainActor
final class CollectionFolderViewModel {
    struct Tab: Identifiable {
        let source: CollectionSource
        var title: String
        var items: [MetaPreview] = []
        var isLoading = false
        var hasMore = true
        var unavailable: CollectionSourceResolver.Unavailable?
        var page = 0
        /// Raw catalog offset used by addon sources. Unlike a fixed page size,
        /// this follows whatever number of items the addon actually returned.
        var sourceOffset = 0

        var id: String { source.id }
    }

    private(set) var tabs: [Tab] = []
    private var loadedFolderId: String?

    /// Every source's items in one list, de-duplicated. Backs the "All" tab.
    var combined: [MetaPreview] {
        var seen = Set<String>()
        return tabs.flatMap(\.items).filter { seen.insert($0.rowKey).inserted }
    }

    /// Set when nothing could be reached at all. A folder whose only source needs a TMDB key
    /// should say so; a folder where one of three failed should just show the other two.
    var blockingReason: CollectionSourceResolver.Unavailable? {
        guard !tabs.isEmpty, tabs.allSatisfy({ $0.items.isEmpty }) else { return nil }
        return tabs.compactMap(\.unavailable).first
    }

    var isLoading: Bool { tabs.contains(where: \.isLoading) }

    func load(folder: CollectionFolder, addons: AddonStore, settings: AppSettings) async {
        guard loadedFolderId != folder.id else { return }
        loadedFolderId = folder.id
        tabs = folder.sources.enumerated().map { index, source in
            Tab(source: source, title: source.title?.nilIfBlank ?? Self.fallbackTitle(source, index: index, addons: addons))
        }
        // First pages in parallel: a folder with four sources should not take four round trips
        // before it draws anything.
        await withTaskGroup(of: Void.self) { group in
            for tab in tabs {
                group.addTask { @MainActor in await self.loadMore(tab.id, addons: addons, settings: settings) }
            }
        }
    }

    func loadMore(_ tabId: String, addons: AddonStore, settings: AppSettings) async {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }),
              !tabs[index].isLoading, tabs[index].hasMore
        else { return }

        tabs[index].isLoading = true
        let nextPage = tabs[index].page + 1
        let sourceOffset = tabs[index].sourceOffset
        let page = await CollectionSourceResolver.items(
            for: tabs[index].source,
            page: nextPage,
            skip: sourceOffset,
            addons: addons,
            settings: settings
        )

        // The array may have been replaced while this was in flight.
        guard let current = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[current].isLoading = false
        tabs[current].page = nextPage
        tabs[current].sourceOffset += page.items.count
        tabs[current].unavailable = page.unavailable
        tabs[current].hasMore = page.hasMore
        var seen = Set(tabs[current].items.map(\.rowKey))
        tabs[current].items += page.items.filter { seen.insert($0.rowKey).inserted }
    }

    /// An addon source carries no title of its own — the catalogue's own name is the honest one.
    private static func fallbackTitle(_ source: CollectionSource, index: Int, addons: AddonStore) -> String {
        guard case .addon(let addon) = source else { return "Source \(index + 1)" }

        let catalogName = addons.enabledAddons
            .first { $0.id == addon.addonId }?
            .catalogs.first { $0.id == addon.catalogId }?
            .name ?? addon.catalogId

        if let genre = addon.genre?.nilIfBlank,
           genre.caseInsensitiveCompare("none") != .orderedSame {
            return "\(catalogName) · \(genre)"
        }

        return catalogName
    }
}

/// One folder of a collection, full screen.
struct CollectionFolderView: View {
    @Environment(\.nuvioColors) private var colors
    @Environment(\.posterMetrics) private var metrics
    @Environment(AddonStore.self) private var addons
    @Environment(AppSettings.self) private var settings
    @Environment(CollectionStore.self) private var collections
    @Environment(Router.self) private var router

    let request: CollectionFolderRequest

    @State private var model = CollectionFolderViewModel()
    @State private var selectedTab = 0
    @FocusState private var focusedGridItem: String?
    @State private var lastFocusedGridItem: String?

    private var folder: CollectionFolder? {
        collections.folder(id: request.folderId)?.folder
    }

    /// `FOLLOW_LAYOUT` defers to the viewer's home layout — grid means the tabbed grid, the two
    /// rail layouts mean rails.
    private var viewMode: CollectionViewMode {
        guard let collection = collections.collection(id: request.collectionId) else { return .tabbedGrid }
        guard collection.viewMode == .followLayout else { return collection.viewMode }
        return settings.layout.selectedLayout == .grid ? .tabbedGrid : .rows
    }

    private var showsAllTab: Bool {
        (collections.collection(id: request.collectionId)?.showAllTab ?? true) && model.tabs.count > 1
    }

    private var forcePortraitPosters: Bool {
        collections.collection(id: request.collectionId)?
            .title
            .localizedCaseInsensitiveContains("porn") == true
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: NuvioTheme.spacing.xl) {
                header

                if let reason = model.blockingReason {
                    EmptyStateView(
                        systemImage: "exclamationmark.triangle",
                        title: L10n.text("collection.empty", fallback: "Nothing to show"),
                        message: reason.message
                    )
                    .frame(height: dp(320))
                } else if viewMode == .rows {
                    rows
                } else {
                    tabbedGrid
                }
            }
            .padding(.top, NuvioTheme.layout.tvSafeVertical)
            .padding(.bottom, NuvioTheme.spacing.rail.tailPadding)
        }
        .scrollClipDisabled()
        .background(background)
        .task {
            guard let folder else { return }
            await model.load(folder: folder, addons: addons, settings: settings)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let backdrop = folder?.heroBackdropUrl?.nilIfBlank {
            ZStack {
                RemoteImage(url: backdrop, contentMode: .fill) { colors.background }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                LinearGradient(
                    stops: [
                        .init(color: colors.background.opacity(0.62), location: 0),
                        .init(color: colors.background.opacity(0.92), location: 0.5),
                        .init(color: colors.background, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        } else {
            colors.background
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: NuvioTheme.spacing.xs) {
            if let logo = folder?.titleLogoUrl?.nilIfBlank {
                RemoteImage(url: logo, contentMode: .fit) { EmptyView() }
                    .frame(maxWidth: dp(420), maxHeight: dp(120), alignment: .leading)
            } else {
                Text(folder?.title ?? "")
                    .nuvioText(NuvioTextStyles.display)
                    .foregroundStyle(colors.textPrimary)
            }
            if let collection = collections.collection(id: request.collectionId) {
                Text(collection.title)
                    .nuvioText(NuvioTextStyles.metadata)
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .padding(.horizontal, NuvioTheme.components.row.horizontalPadding)
    }

    /// One rail per source, which is how every other screen in the app presents a list.
    private var rows: some View {
        LazyVStack(alignment: .leading, spacing: NuvioTheme.spacing.rail.rowGap) {
            ForEach(model.tabs) { tab in
                if !tab.items.isEmpty || tab.isLoading {
                    CatalogRowView(
                        title: tab.title,
                        items: tab.items,
                        isLoading: tab.isLoading,
                        showsSeeAll: false,
                        backdropExpandEnabled: false,
                        onSelect: { open($0) },
                        onReachEnd: {
                            Task { await model.loadMore(tab.id, addons: addons, settings: settings) }
                        },
                        forcePortrait: forcePortraitPosters
                    )
                }
            }
        }
    }

    private var tabbedGrid: some View {
        VStack(alignment: .leading, spacing: NuvioTheme.spacing.lg) {
            if showsAllTab || model.tabs.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: NuvioTheme.spacing.sm) {
                        if showsAllTab {
                            NuvioChip(label: "All", isSelected: selectedTab == 0) { selectedTab = 0 }
                        }
                        ForEach(Array(model.tabs.enumerated()), id: \.element.id) { index, tab in
                            let position = showsAllTab ? index + 1 : index
                            NuvioChip(label: tab.title, isSelected: selectedTab == position) {
                                selectedTab = position
                            }
                        }
                    }
                    .padding(.horizontal, NuvioTheme.components.row.horizontalPadding)
                }
                .scrollClipDisabled()
                .focusSection()
            }

            CenteredLazyGrid(columns: metrics.gridColumns(), alignment: .center, spacing: NuvioTheme.spacing.xl) {
                ForEach(Array(gridItems.enumerated()), id: \.element.rowKey) { index, item in
                    ContentCard(
                        item: item,
                        allowsBackdropExpand: false,
                        forcePortrait: forcePortraitPosters,
                        onFocus: { focusedItem in
                            lastFocusedGridItem = focusedItem.rowKey

                            guard index >= max(0, gridItems.count - 8),
                                  let tab = visibleTab,
                                  tab.hasMore,
                                  !tab.isLoading
                            else { return }

                            Task {
                                await model.loadMore(
                                    tab.id,
                                    addons: addons,
                                    settings: settings
                                )
                            }
                        },
                        focusBinding: $focusedGridItem,
                        action: { open(item) }
                    )
                    .id(item.rowKey)
                }
            }
            .padding(.horizontal, NuvioTheme.components.row.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .center)

        }
    }

    private var visibleTab: CollectionFolderViewModel.Tab? {
        let index = showsAllTab ? selectedTab - 1 : selectedTab
        guard index >= 0, model.tabs.indices.contains(index) else { return nil }
        return model.tabs[index]
    }

    private var gridItems: [MetaPreview] {
        visibleTab?.items ?? model.combined
    }

    private func open(_ item: MetaPreview) {
        router.openDetail(item)
    }
}
