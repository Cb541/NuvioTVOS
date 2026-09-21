import Foundation

/// Turns a collection source into titles.
///
/// A folder holds queries, not results, so this is where a folder becomes something to look at.
/// One entry point per source kind, all of them paged, and every failure is an empty page rather
/// than a throw — a folder with three sources should show the two that answered.
@MainActor
enum CollectionSourceResolver {
    /// What a source could not deliver, so a folder can say why it is empty instead of just
    /// being empty. A missing key is the common case and the viewer can act on it.
    enum Unavailable: Equatable {
        case needsTmdbKey
        case needsTraktAccount
        case addonMissing(String)

        var message: String {
            switch self {
            case .needsTmdbKey:
                return "This folder needs a TMDB API key. Add one in Settings → Integrations."
            case .needsTraktAccount:
                return "This folder needs a connected Trakt account."
            case .addonMissing(let id):
                return "The addon this folder uses is not installed: \(id)."
            }
        }
    }

    struct Page {
        var items: [MetaPreview] = []
        var unavailable: Unavailable?
        /// False once a page comes back short, so a rail stops asking for more.
        var hasMore: Bool = false
    }

    static func items(
        for source: CollectionSource,
        page: Int,
        skip: Int? = nil,
        addons: AddonStore,
        settings: AppSettings
    ) async -> Page {
        switch source {
        case .addon(let source):
            return await addonItems(source, page: page, skip: skip, addons: addons)
        case .tmdb(let source):
            return await tmdbItems(source, page: page, settings: settings)
        case .trakt(let source):
            return await traktItems(source, page: page, settings: settings)
        }
    }

    // MARK: Addon catalogues

    private static func addonItems(
        _ source: AddonCollectionSource,
        page: Int,
        skip: Int?,
        addons: AddonStore
    ) async -> Page {
        // Android keys these by manifest id, and so does `Addon.id`, so the two apps agree on
        // what a source points at even though the base URLs differ per installation.
        guard let addon = addons.enabledAddons.first(where: { $0.id == source.addonId }) else {
            return Page(unavailable: .addonMissing(source.addonId))
        }

        let catalog = addon.catalogs.first {
            $0.id == source.catalogId && $0.apiType == source.type
        }
        let declaredPageSize = catalog?.pageSize.flatMap { $0 > 0 ? $0 : nil }

        var extras: [(String, String)] = []
        if let genre = source.genre?.nilIfBlank,
           genre.caseInsensitiveCompare("none") != .orderedSame {
            extras.append(("genre", genre))
        }

        let effectiveSkip = max(
            0,
            skip ?? ((page - 1) * (declaredPageSize ?? 20))
        )

        let items = (try? await StremioClient.shared.fetchCatalog(
            addon: addon,
            type: source.type,
            catalogId: source.catalogId,
            skip: effectiveSkip,
            extraArgs: extras
        )) ?? []

        let hasMore = declaredPageSize.map {
            items.count >= $0
        } ?? !items.isEmpty

        return Page(items: items, hasMore: hasMore)
    }

    // MARK: TMDB

    private static func tmdbItems(
        _ source: TmdbCollectionSource,
        page: Int,
        settings: AppSettings
    ) async -> Page {
        let key = settings.tmdb.apiKey
        guard !key.isEmpty else { return Page(unavailable: .needsTmdbKey) }
        let language = settings.tmdb.language
        let type = source.mediaType.contentType

        let items: [MetaPreview]
        switch source.sourceType {
        case .discover:
            items = await TMDBClient.shared.discover(
                type: type,
                query: TMDBDiscoverQuery(sortBy: source.sortBy, filters: source.filters),
                page: page,
                apiKey: key,
                language: language
            )
        case .company, .network, .person, .director, .list, .collection:
            guard let tmdbId = source.tmdbId else { return Page() }
            items = await TMDBClient.shared.collectionItems(
                kind: source.sourceType,
                tmdbId: tmdbId,
                type: type,
                sortBy: source.sortBy,
                page: page,
                apiKey: key,
                language: language
            )
        }
        // TMDB pages 20 at a time; a short page is the last one.
        return Page(items: items, hasMore: items.count >= 20)
    }

    // MARK: Trakt

    private static func traktItems(
        _ source: TraktCollectionSource,
        page: Int,
        settings: AppSettings
    ) async -> Page {
        let clientId = settings.tracking.traktClientId
        guard !clientId.isEmpty else { return Page(unavailable: .needsTraktAccount) }

        // A Trakt list is served whole rather than paged, so only the first page has anything.
        guard page <= 1 else { return Page() }
        let items = await TraktClient.shared.listItems(
            listId: source.traktListId,
            type: source.mediaType.contentType,
            sortBy: source.sortBy,
            sortHow: source.sortHow,
            clientId: clientId,
            token: settings.tracking.traktAccessToken.nilIfBlank
        )
        return Page(items: items)
    }
}
