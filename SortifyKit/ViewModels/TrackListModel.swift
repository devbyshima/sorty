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
        /// Nothing to show and nothing went wrong: a rule of Spotify's answers
        /// this playlist, and the state carries the words for it. Distinct from
        /// `failed` because a rule is not an error, offers no Try Again, and
        /// deserves the empty-state treatment rather than the error row.
        case unavailable(EmptyState)
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
    /// failed - so in the common case, where some did, nothing said anything.
    private var providerNote: String?
    /// Oldest `added_at` in the playlist - the closest thing Spotify offers to a
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
    /// rather than recomputed - without this, resolving the range per row would
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
    /// had nothing for is still written back - appended at the end rather than
    /// dropped - because using Sortify must never cost a listener tracks.
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
        let resolved = order(rows.filter { filter.accepts($0) })
        arrangementCache = resolved
        return resolved
    }

    /// Every track in the playlist, in Arrangement order - the filter not
    /// consulted.
    ///
    /// This is the *only* thing overwrite is allowed to write (ADR-0002). It is
    /// a separate list from `arrangedRows`, and deliberately so: the two save
    /// paths differ in exactly one respect, which list they carry, so making
    /// that one respect two named values is what stops the difference being
    /// erased by someone passing a flag.
    ///
    /// Uncached. It is read when a save happens, not once per row.
    public var fullOrder: [TrackRow] {
        let resolved = order(rows)
        return resolved.ranked + resolved.groups.flatMap(\.rows)
    }

    private func order(_ rows: [TrackRow]) -> (ranked: [TrackRow], groups: [UnrankableGroup]) {
        let split = PlaylistSorter.partition(rows, by: arrangement)
        let groups = arrangement.rankingAttribute.map {
            UnrankableGroup.groups(for: split.unrankable, attribute: $0, providerNote: providerNote)
        } ?? []
        return (split.ranked, groups)
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
    /// Resolved against `rows` - the whole loaded playlist - for the same
    /// reason `positionRange` is: a track hidden by the filter is still one of
    /// the others this one is being compared against. Not cached, because it is
    /// computed once per tap rather than once per row.
    public func detail(for row: TrackRow) -> TrackDetail {
        TrackDetail(row: row, in: rows)
    }

    /// What the toolbar offers, in the order it offers it.
    public var saveActions: [SaveAction] {
        SaveAction.actions(
            writtenCount: newPlaylistURIs.count,
            isFiltered: filter.isActive,
            canCreate: canSaveAsNewPlaylist,
            canOverwrite: canOverwrite,
            mayOverwriteThisPlaylist: mayOverwriteThisPlaylist
        )
    }

    /// Whether the Save control is worth reaching for at all.
    public var canSave: Bool { saveActions.contains { $0.isEnabled } }

    /// A new playlist is a duplicate unless *something* differs from what's on
    /// Spotify - and the filter counts, because a filter is the whole reason
    /// story 41 wants this path.
    public var canSaveAsNewPlaylist: Bool {
        guard isReadyToWrite, let saved else { return false }
        return saved != current && !arrangedRows.isEmpty
    }

    /// Armed by a change of **Arrangement alone**.
    ///
    /// This is ADR-0002 showing up in the gate rather than only in the payload.
    /// Overwrite never consults the filter, so narrowing the filter cannot
    /// leave the playlist on Spotify stale - the order it holds is still the
    /// order this screen would write. Offering it there would be offering a
    /// write with nothing to write.
    public var canOverwrite: Bool {
        guard isReadyToWrite, mayOverwriteThisPlaylist, let saved else { return false }
        return saved.arrangement != arrangement
    }

    /// Whether this playlist is one Sortify may write over at all - a question
    /// about the playlist, not about whether anything has changed.
    public var mayOverwriteThisPlaylist: Bool {
        service.canWriteBack && playlist.isWritable(byUserID: currentUserID)
    }

    private var isReadyToWrite: Bool {
        guard case .ready = phase, saveStatus != .saving else { return false }
        return service.canWriteBack
    }

    public var canWriteBack: Bool { service.canWriteBack }

    private func invalidateArrangement() {
        arrangementCache = nil
        rangeCache = nil
    }

    // MARK: - Loading

    public func load() async {
        rows = []
        albumReleaseDates = [:]
        saved = nil
        invalidateArrangement()

        // Known before asking. Spotify sends a playlist's contents only to the
        // people who own it or collaborate on it, and who owns this one arrived
        // with the library listing, so the answer is already in hand: a request
        // here would spend one of a five-listener quota to be told 403 and would
        // put a spinner in front of a sentence that was true on arrival.
        //
        // Only another listener's playlist is pre-empted. Spotify's own
        // editorial and algorithmic playlists fail the same rule for a different
        // reason and keep the explanation `LoadFailure` gives them.
        if playlist.category(currentUserID: currentUserID) == .other,
           !playlist.contentsAreReadable(byUserID: currentUserID) {
            phase = .unavailable(.contentsWithheld(owner: LoadFailure.ownerName(of: playlist)))
            canRetryLoad = false
            return
        }

        phase = .loading(loaded: 0, total: playlist.tracks.total)

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
                        addedAt: item.addedAt,
                        // Already here, in the track's own album. Reading it at
                        // construction rather than in `enrich()` is what makes a
                        // release date independent of a network call.
                        albumReleaseDate: playable.album?.validReleaseDate
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
        } catch let error as SpotifyAPIError where error.isNotWritable
            && playlist.category(currentUserID: currentUserID) == .other {
            // The same refusal the pre-check makes without asking, arriving from
            // the wire instead: a collaborative playlist whose invite was
            // withdrawn, or an owner Spotify never named. One state, so the
            // screen reads the same either way.
            phase = .unavailable(.contentsWithheld(owner: LoadFailure.ownerName(of: playlist)))
            canRetryLoad = false
        } catch {
            // Not `localizedDescription`: Spotify answers most refusals with a
            // bare "Forbidden", which told the listener nothing about whose
            // rule it was or whether retrying could help. `LoadFailure` reads
            // the status and the playlist together, because the status alone
            // never says which refusal this is.
            phase = .failed(
                LoadFailure.message(for: error, playlist: playlist, currentUserID: currentUserID)
            )
            canRetryLoad = LoadFailure.isWorthRetrying(
                error, playlist: playlist, currentUserID: currentUserID
            )
        }
    }

    /// False when the refusal is a rule that will refuse the next request too.
    /// A Try Again button that cannot succeed is worse than no button.
    public private(set) var canRetryLoad = true

    /// Fills in audio features, and the release date of any album that arrived
    /// without one. Neither is fatal - the list is useful without them, and on a
    /// post-2024 Spotify app the feature call will simply come back empty.
    ///
    /// Release dates are *not* fetched in the general case: they come with the
    /// playlist (`TrackRow.albumReleaseDate`). The lookup here is for the album
    /// that somehow carried none, which normally means no album is asked about at
    /// all.
    private func enrich() async {
        let trackIDs = rows.compactMap { row -> String? in
            guard !row.playable.isEpisode, let id = row.playable.id else { return nil }
            return id
        }

        async let features: [String: AudioFeatures] = {
            (try? await featureProvider.features(forTrackIDs: trackIDs)) ?? [:]
        }()

        // Only the albums that arrived without a release date - normally none, so
        // normally no request. Asking about all of them was what broke this: the
        // answer was thrown away on success and, once February 2026 removed batch
        // `/albums` for new apps, replaced every date with the nil of a refusal.
        let albumIDs = Array(Set(rows.compactMap { row -> String? in
            guard row.albumReleaseDate == nil else { return nil }
            return row.playable.album?.id
        }))
        async let albums: [TrackAlbum] = {
            (try? await service.albums(ids: albumIDs)) ?? []
        }()

        let (resolvedFeatures, resolvedAlbums) = await (features, albums)

        for album in resolvedAlbums {
            if let id = album.id, let date = album.validReleaseDate {
                albumReleaseDates[id] = date
            }
        }

        for index in rows.indices {
            if let id = rows[index].playable.id {
                rows[index].features = resolvedFeatures[id]
            }
            // Fills a gap, never replaces what the track came with. An album the
            // lookup had nothing for leaves the row exactly as it was.
            if rows[index].albumReleaseDate == nil,
               let albumID = rows[index].playable.album?.id,
               let date = albumReleaseDates[albumID] {
                rows[index].albumReleaseDate = date
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
    /// direction everywhere else - one gesture meaning two things depending on
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

    /// Runs the action the toolbar was tapped on.
    ///
    /// A switch, not a parameter. `Kind` reaches exactly one of the two methods
    /// below and neither of them ever learns which control was tapped, so there
    /// is no value anywhere that could be threaded into the wrong payload.
    public func perform(_ kind: SaveAction.Kind) async {
        switch kind {
        case .overwrite: await overwrite()
        case .newPlaylist: await saveAsNewPlaylist()
        }
    }

    /// What overwrite writes: the whole playlist, reordered.
    private var overwriteURIs: [String] { fullOrder.compactMap(\.savableURI) }

    /// What save-as-new writes: what is on screen, filter and all.
    private var newPlaylistURIs: [String] { arrangedRows.compactMap(\.savableURI) }

    /// Replaces the playlist's contents with **every one of its tracks**, in
    /// Arrangement order.
    ///
    /// ADR-0002. The filter is a view onto the arrangement and is not consulted
    /// here, so no sequence of taps in Sortify can remove a track from a
    /// playlist the listener already has. The invariant is structural: this
    /// method cannot be handed a shorter list, because it is not handed a list
    /// at all.
    ///
    /// Kept a separate method from `saveAsNewPlaylist()` on purpose. Folding
    /// the two back into one path with a flag reads as a tidy-up and is exactly
    /// how a 68-track playlist becomes 20 with no undo.
    public func overwrite() async {
        let uris = overwriteURIs
        guard !uris.isEmpty else {
            saveStatus = .failed("Nothing to save. None of these tracks can be written back to Spotify.")
            return
        }

        saveStatus = .saving
        let arrangementName = arrangement.name

        do {
            try await service.replaceTracks(playlistID: playlist.id, uris: uris)
            saved = current
            saveStatus = .updated("Updated “\(playlist.name)” with \(uris.count) tracks by \(arrangementName).")
        } catch {
            saveStatus = .failed(Self.failureMessage(for: error))
        }
    }

    /// Creates a new playlist holding what is on screen - which may be a
    /// subset, and is the only path that may be.
    public func saveAsNewPlaylist() async {
        let uris = newPlaylistURIs
        guard !uris.isEmpty else {
            saveStatus = .failed("Nothing to save. The BPM filter is hiding every track.")
            return
        }
        guard let userID = currentUserID else {
            saveStatus = .failed("Sortify doesn't know which account to save to.")
            return
        }

        saveStatus = .saving
        let arrangementName = arrangement.name

        do {
            let created = try await service.createPlaylist(
                userID: userID,
                name: SaveNaming.playlistName(original: playlist.name, arrangement: arrangement),
                isPublic: playlist.isPublic ?? false,
                description: SaveNaming.playlistDescription(
                    original: playlist.cleanDescription, arrangement: arrangement
                )
            )
            try await service.replaceTracks(playlistID: created.id, uris: uris)

            saved = current
            saveStatus = .created("Created “\(created.name)” with \(uris.count) tracks by \(arrangementName).")
        } catch {
            saveStatus = .failed(Self.failureMessage(for: error))
        }
    }

    /// Shared because it is about the *error*, not about the payload - the one
    /// thing the two paths may legitimately have in common.
    private static func failureMessage(for error: any Error) -> String {
        if let apiError = error as? SpotifyAPIError, apiError.isNotWritable {
            return "This playlist can't be modified. It may be owned by Spotify or another listener. Save a new playlist instead."
        }
        return error.localizedDescription
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
