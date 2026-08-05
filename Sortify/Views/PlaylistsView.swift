import SwiftUI

struct PlaylistsView: View {
    @Environment(SessionModel.self) private var session
    let onSelect: (Playlist) -> Void

    private let columns = [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 16)]

    var body: some View {
        @Bindable var session = session

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // iOS 27's tabs picker style — reads as a segmented row of
                // categories without the cramped look of .segmented at six items.
                Picker("Show", selection: $session.categoryFilter) {
                    ForEach(PlaylistFilter.allCases) { filter in
                        Text("\(filter.label) (\(session.count(for: filter)))").tag(filter)
                    }
                }
                .pickerStyle(.tabs)
                .padding(.horizontal, 16)

                if case .loading(let loaded, let total) = session.playlistLoad {
                    LoadProgressRow(loaded: loaded, total: total, noun: "playlists")
                        .padding(.horizontal, 16)
                }

                if case .failed(let message) = session.playlistLoad {
                    ErrorRow(message: message) {
                        Task { await session.loadPlaylists() }
                    }
                    .padding(.horizontal, 16)
                }

                if session.filteredPlaylists.isEmpty, case .ready = session.playlistLoad {
                    ContentUnavailableView(
                        "No playlists match",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different category or clear the search.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(session.filteredPlaylists) { playlist in
                            PlaylistCard(
                                playlist: playlist,
                                category: playlist.category(currentUserID: session.user?.id)
                            )
                            .onTapGesture { onSelect(playlist) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 12)
        }
        .background(SortifyTheme.background)
        .navigationTitle("Pick a playlist")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $session.searchText, prompt: "Filter by name")
        .refreshable { await session.loadPlaylists() }
    }
}

private struct PlaylistCard: View {
    let playlist: Playlist
    let category: PlaylistCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverImage(url: playlist.cardImageURL)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))

            Text(playlist.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Text("\(playlist.tracks.total) tracks")
                if playlist.collaborative {
                    Image(systemName: "person.2.fill")
                        .accessibilityLabel("Collaborative")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(SortifyTheme.surface, in: .rect(cornerRadius: 16))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(playlist.name), \(playlist.tracks.total) tracks, \(category.label)")
        .accessibilityAddTraits(.isButton)
    }
}

struct LoadProgressRow: View {
    let loaded: Int
    let total: Int?
    let noun: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(total.map { "Loaded \(loaded) of \($0) \(noun)…" } ?? "Loaded \(loaded) \(noun)…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let total, total > 0 {
                ProgressView(value: Double(min(loaded, total)), total: Double(total))
                    .progressViewStyle(.linear)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ErrorRow: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.footnote)
                if let retry {
                    Button("Try Again", action: retry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}
