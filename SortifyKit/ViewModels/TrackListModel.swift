import Foundation
import Observation

/// Drives one playlist: loading, arranging, filtering, saving.
@MainActor
@Observable
public final class TrackListModel {
    public enum LoadPhase: Equatable {
        case idle
        case loading(loaded: Int, total: Int)
        case ready
        case failed(String)
        case empty
    }

    public let playlist: Playlist
    /// Invalidates on write rather than at each call site: `enrich()` mutates
    /// rows and then suspends before it could invalidate by hand, and a render
    /// landing in that window would read a range resolved from rows that had no
    /// features yet.
    public private(set) var rows: [TrackRow] = [] { didSet { invalidateArrangement() } }
    public private(set) var phase: LoadPhase = .idle
    /// The audio-feature source's own account of why it came up short, carried
    /// into whichever unrankable group it explains.
    ///
    /// It used to be a notice above the list, shown only when *every* track
    /// failed — so in the common case, where some did, nothing said anything.
    private var providerNote: String?
    /// Oldest `added_at` in the playlist — the closest thing Spotify offers to a
    /// creation date.
    public private(set) var oldestAddedAt: String?

    /// The app's single piece of ordering state. Direction lives inside the
    /// Arrangement, so there is nothing for it to fall out of step with.
    public private(set) var arrangement: Arrangement = .originalOrder {
        didSet { invalidateArrangement() }
    }
    public var filter = BPMFilter() { didSet { invalidateArrangement() } }

    public private(set) var saveStatus: SaveStatus = .idle
    public enum SaveStatus: Equatable {
        case idle
        case saving
        case created(String)
        case updated(String)
        case failed(String)
    }

    private let service: any MusicService
    private let featureProvider: any AudioFeatureProviding
    private let currentUserID: String?
    private var albumReleaseDates: [String: String] = [:]
    /// What was last written to Spotify. Nil until the first load finishes,
    /// which is what keeps Save disabled on arrival.
    ///
    /// Private, and deliberately not a public pair type: ADR-0002 splits the
    /// two save paths, and a public `(arrangement, filter)` value is exactly
    /// the shape parallel direction state would grow back on.
    private struct Saved: Equatable {
        var arrangement: Arrangement
        var filter: BPMFilter
    }
    private var saved: Saved?

    /// Both caches are read on every row of a long list, so they are memoized
    /// rather than recomputed — without this, resolving the range per row would
    /// make drawing the list O(n²).
    ///
    /// Both are observation-tracked stored properties, and on a cache hit the
    /// getter touches neither `rows` nor `arrangement`. The cache *write* is
    /// what registers the dependency, so marking either `@ObservationIgnored`
    /// would stop the list redrawing when the arrangement changes.
    private var arrangementCache: (ranked: [TrackRow], groups: [UnrankableGroup])?
    /// Doubly optional on purpose: the outer nil is "not computed", the inner
    /// is "computed, and this Arrangement has no bars".
    private var rangeCache: AttributeRange??

    public init(
        playlist: Playlist,
        service: any MusicService,
        featureProvider: any AudioFeatureProviding,
        currentUserID: String?
    ) {
        self.playlist = playlist
        self.service = service
        self.featureProvider = featureProvider
        self.currentUserID = currentUserID
    }

    // MARK: - Derived state

    private var current: Saved { Saved(arrangement: arrangement, filter: filter) }

    /// Every visible row, in exactly the order they appear on screen: what the
    /// Arrangement ranked, then each unrankable group in the order its header
    /// is shown.
    ///
    /// The unrankable ones are deliberately part of this. A track the provider
    /// had nothing for is still written back — appended at the end rather than
    /// dropped — because using Sortify must never cost a listener tracks.
    ///
    /// Display order and write order are the same list on purpose: a listener
    /// who can see the order should be able to trust that it is what gets
    /// saved. (What that order is *filtered* to is a separate question, and
    /// ADR-0002 splits it per save path in ticket 07.)
    public var arrangedRows: [TrackRow] {
        let split = arranged
        return split.ranked + split.groups.flatMap(\.rows)
    }

    /// What the Arrangement placed, which is what the list shows before the
    /// group headers.
    public var rankedRows: [TrackRow] { arranged.ranked }

    /// What it couldn't, gathered under headers that say how many and why.
    /// Empty whenever everything ranked, so no header appears.
    public var unrankableGroups: [UnrankableGroup] { arranged.groups }

    private var arranged: (ranked: [TrackRow], groups: [UnrankableGroup]) {
        if let arrangementCache { return arrangementCache }

        let filtered = rows.filter { filter.accepts($0) }
        let split = PlaylistSorter.partition(filtered, by: arrangement)
        let groups = arrangement.rankingAttribute.map {
            UnrankableGroup.groups(for: split.unrankable, attribute: $0, providerNote: providerNote)
        } ?? []

        let resolved = (ranked: split.ranked, groups: groups)
        arrangementCache = resolved
        return resolved
    }

    public var hiddenRowCount: Int { rows.count - arrangedRows.count }

    /// The span the rows' bars are drawn against, or nil when there should be
    /// no bars at all.
    ///
    /// Resolved from `rows` rather than `arrangedRows`: a track hidden by the
    /// filter is still part of the playlist the others are being compared
    /// against, and letting the filter move the range would make the same track
    /// change length depending on what else was on screen.
    public var positionRange: AttributeRange? {
        if let cached = rangeCache { return cached }
        let resolved = resolvePositionRange()
        rangeCache = .some(resolved)
        return resolved
    }

    private func resolvePositionRange() -> AttributeRange? {
        guard let attribute = arrangement.rankingAttribute,
              // A bar under a value the row doesn't print would be a bar under
              // nothing, and a bar for position is a ramp down a list already
              // in that order.
              !TrackRowText.isAlreadyVisible(attribute)
        else { return nil }
        return AttributeRange(attribute: attribute, rows: rows)
    }


    /// One track in full, for the detail sheet.
    ///
    /// Resolved against `rows` — the whole loaded playlist — for the same
    /// reason `positionRange` is: a track hidden by the filter is still one of
    /// the others this one is being compared against. Not cached, because it is
    /// computed once per tap rather than once per row.
    public func detail(for row: TrackRow) -> TrackDetail {
        TrackDetail(row: row, in: rows)
    }

    /// Save is offered only once something actually differs from what's on
    /// Spotify — matching the reference, where an untouched playlist can't be
    /// re-saved into a pointless duplicate.
    public var canSave: Bool {
        guard case .ready = phase, saveStatus != .saving else { return false }
        guard let saved else { return false }
        return saved != current && !arrangedRows.isEmpty
    }

    public var canOverwrite: Bool {
        service.canWriteBack && playlist.isWritable(byUserID: currentUserID)
    }

    public var canWriteBack: Bool { service.canWriteBack }

    private func invalidateArrangement() {
        arrangementCache = nil
        rangeCache = nil
    }

    // MARK: - Loading

    public func load() async {
        phase = .loading(loaded: 0, total: playlist.tracks.total)
        rows = []
        albumReleaseDates = [:]
        saved = nil
        invalidateArrangement()

        do {
            let collected = Mailbox()
            _ = try await service.playlistItems(
                playlistID: playlist.id,
                ownerID: playlist.owner.id
            ) { page, loadedCount in
                await collected.append(page, loaded: loadedCount)
            }

            var index = 0
            var newRows: [TrackRow] = []
            for item in await collected.items {
                guard let playable = item.track else { continue }
                newRows.append(
                    TrackRow(
                        originalIndex: index,
                        playable: playable,
                        addedAt: item.addedAt
                    )
                )
                index += 1
            }

            rows = newRows
            oldestAddedAt = newRows.compactMap { validAddedAt($0.addedAt) }.min()

            guard !rows.isEmpty else {
                phase = .empty
                return
            }

            phase = .loading(loaded: rows.count, total: rows.count)

            await enrich()

            var mutableRows = rows
            ArtistSeparation.assignIndices(to: &mutableRows)
            rows = mutableRows

            invalidateArrangement()
            saved = current
            phase = .ready
        } catch is CancellationError {
            // Leaving the screen mid-load is not a failure.
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Fills in audio features and album release dates. Neither is fatal — the
    /// list is useful without them, and on a post-2024 Spotify app the feature
    /// call will simply come back empty.
    private func enrich() async {
        let trackIDs = rows.compactMap { row -> String? in
            guard !row.playable.isEpisode, let id = row.playable.id else { return nil }
            return id
        }

        async let features: [String: AudioFeatures] = {
            (try? await featureProvider.features(forTrackIDs: trackIDs)) ?? [:]
        }()

        let albumIDs = Array(Set(rows.compactMap { $0.playable.album?.id }))
        async let albums: [TrackAlbum] = {
            (try? await service.albums(ids: albumIDs)) ?? []
        }()

        let (resolvedFeatures, resolvedAlbums) = await (features, albums)

        for album in resolvedAlbums {
            if let id = album.id, let date = album.releaseDate {
                albumReleaseDates[id] = date
            }
        }

        for index in rows.indices {
            if let id = rows[index].playable.id {
                rows[index].features = resolvedFeatures[id]
            }
            if let albumID = rows[index].playable.album?.id {
                rows[index].albumReleaseDate = albumReleaseDates[albumID]
            }
        }

        // Asked for whenever the source fell short of the tracks it was given,
        // not only when it returned nothing at all. Deduplicated first: a
        // playlist may legitimately hold the same track twice, and the features
        // come back keyed by id, so a duplicate would look like a miss.
        providerNote = resolvedFeatures.count < Set(trackIDs).count
            ? await featureProvider.unavailabilityReason
            : nil
        invalidateArrangement()
    }

    // MARK: - Interaction

    /// The only mutator of ordering state, so there is exactly one place it can
    /// change.
    public func apply(_ arrangement: Arrangement) {
        self.arrangement = arrangement
    }

    /// Draws a new shuffle.
    ///
    /// Its own control, deliberately: the old table re-rolled when you tapped
    /// the Random column a second time, which is the same gesture that flipped
    /// direction everywhere else — one gesture meaning two things depending on
    /// where it landed (ADR-0001).
    ///
    /// The new seed is part of the Arrangement, so a re-roll is a change like
    /// any other and Save notices it.
    public func reroll() {
        var seed = UInt64.random(in: .min ... .max)
        if case .shuffle(let current) = arrangement, seed == current { seed &+= 1 }
        apply(.shuffle(seed: seed))
    }

    // MARK: - Saving

    public func save(createNew: Bool) async {
        let uris = arrangedRows.compactMap(\.savableURI)
        guard !uris.isEmpty else {
            saveStatus = .failed("Nothing to save — the BPM filter is hiding every track.")
            return
        }

        saveStatus = .saving
        let arrangementName = arrangement.name

        do {
            let target: Playlist
            if createNew {
                guard let userID = currentUserID else {
                    saveStatus = .failed("Sortify doesn't know which account to save to.")
                    return
                }
                target = try await service.createPlaylist(
                    userID: userID,
                    name: SaveNaming.playlistName(original: playlist.name, arrangement: arrangement),
                    isPublic: playlist.isPublic ?? false,
                    description: SaveNaming.playlistDescription(
                        original: playlist.cleanDescription, arrangement: arrangement
                    )
                )
            } else {
                target = playlist
            }

            try await service.replaceTracks(playlistID: target.id, uris: uris)

            saved = current
            saveStatus = createNew
                ? .created("Created “\(target.name)” — \(uris.count) tracks by \(arrangementName).")
                : .updated("Updated “\(playlist.name)” — \(uris.count) tracks by \(arrangementName).")
        } catch let error as SpotifyAPIError where error.isNotWritable {
            saveStatus = .failed(
                "This playlist can't be modified — it may be owned by Spotify or another listener. Save a new playlist instead."
            )
        } catch {
            saveStatus = .failed(error.localizedDescription)
        }
    }

    public func clearSaveStatus() { saveStatus = .idle }
}

/// Collects streamed pages. The service hands pages to a `@Sendable` closure
/// that can run off the main actor, so the accumulation needs its own isolation.
private actor Mailbox {
    private(set) var items: [PlaylistItem] = []
    private(set) var loaded = 0

    func append(_ page: [PlaylistItem], loaded: Int) {
        items.append(contentsOf: page)
        self.loaded = loaded
    }
}
