import Foundation
import Observation

/// Drives the sort table for one playlist: loading, sorting, filtering, saving.
@MainActor
@Observable
public final class TrackTableModel {
    public enum LoadPhase: Equatable {
        case idle
        case loading(loaded: Int, total: Int)
        case ready
        case failed(String)
        case empty
    }

    public let playlist: Playlist
    public private(set) var rows: [TrackRow] = []
    public private(set) var phase: LoadPhase = .idle
    /// Explains blank acoustic columns when the feature source can't serve them.
    public private(set) var featureNotice: String?
    /// Oldest `added_at` in the playlist — the closest thing Spotify offers to a
    /// creation date.
    public private(set) var oldestAddedAt: String?

    public var sortColumn: SortColumn = .order { didSet { invalidateArrangement() } }
    public var sortDirection: SortDirection = .ascending { didSet { invalidateArrangement() } }
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
    /// The arrangement last written to Spotify. Nil until the first load
    /// finishes, which is what keeps Save disabled on arrival.
    private var savedState: SortState?
    private var arrangementCache: [TrackRow]?

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

    public var currentState: SortState {
        SortState(column: sortColumn, direction: sortDirection, filter: filter)
    }

    /// Rows in display order, after filtering.
    public var arrangedRows: [TrackRow] {
        if let arrangementCache { return arrangementCache }
        let arranged = PlaylistSorter.arrange(rows, state: currentState)
        arrangementCache = arranged
        return arranged
    }

    public var hiddenRowCount: Int { rows.count - arrangedRows.count }

    /// Save is offered only once something actually differs from what's on
    /// Spotify — matching the reference, where an untouched playlist can't be
    /// re-saved into a pointless duplicate.
    public var canSave: Bool {
        guard case .ready = phase, saveStatus != .saving else { return false }
        guard let savedState else { return false }
        return savedState != currentState && !arrangedRows.isEmpty
    }

    public var canOverwrite: Bool {
        service.canWriteBack && playlist.isWritable(byUserID: currentUserID)
    }

    public var canWriteBack: Bool { service.canWriteBack }

    private func invalidateArrangement() { arrangementCache = nil }

    // MARK: - Loading

    public func load() async {
        phase = .loading(loaded: 0, total: playlist.tracks.total)
        rows = []
        albumReleaseDates = [:]
        savedState = nil
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
                        addedAt: item.addedAt,
                        randomValue: Int.random(in: 0..<10_000)
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
            savedState = currentState
            phase = .ready
        } catch is CancellationError {
            // Leaving the screen mid-load is not a failure.
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Fills in audio features and album release dates. Neither is fatal — the
    /// table is useful without them, and on a post-2024 Spotify app the feature
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

        featureNotice = resolvedFeatures.isEmpty ? await featureProvider.unavailabilityReason : nil
        invalidateArrangement()
    }

    // MARK: - Interaction

    /// Tapping a header: same column flips direction, a new column starts
    /// ascending, and the Random column re-rolls so repeat taps reshuffle.
    public func selectColumn(_ column: SortColumn) {
        if column == sortColumn {
            if column.directionMatters {
                sortDirection = sortDirection.toggled
            }
        } else {
            sortColumn = column
            sortDirection = .ascending
        }

        if column == .rnd {
            var mutableRows = rows
            PlaylistSorter.reroll(&mutableRows)
            rows = mutableRows
        }
        invalidateArrangement()
    }

    // MARK: - Saving

    public func save(createNew: Bool) async {
        let uris = arrangedRows.compactMap(\.savableURI)
        guard !uris.isEmpty else {
            saveStatus = .failed("Nothing to save — the BPM filter is hiding every track.")
            return
        }

        saveStatus = .saving
        let sortName = SaveNaming.sortName(column: sortColumn, direction: sortDirection)

        do {
            let target: Playlist
            if createNew {
                guard let userID = currentUserID else {
                    saveStatus = .failed("Sortify doesn't know which account to save to.")
                    return
                }
                target = try await service.createPlaylist(
                    userID: userID,
                    name: SaveNaming.playlistName(
                        original: playlist.name, column: sortColumn, direction: sortDirection
                    ),
                    isPublic: playlist.isPublic ?? false,
                    description: SaveNaming.playlistDescription(
                        original: playlist.cleanDescription, column: sortColumn, direction: sortDirection
                    )
                )
            } else {
                target = playlist
            }

            try await service.replaceTracks(playlistID: target.id, uris: uris)

            savedState = currentState
            saveStatus = createNew
                ? .created("Created “\(target.name)” — \(uris.count) tracks by \(sortName).")
                : .updated("Updated “\(playlist.name)” — \(uris.count) tracks by \(sortName).")
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
