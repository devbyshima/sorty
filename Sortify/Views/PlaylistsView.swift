import SwiftUI

/// Pick a playlist.
///
/// Was a two-up grid of artwork tiles: four playlists per screen, most of each
/// one empty square, and a six-segment category picker whose last four labels
/// truncated to fragments. Rows fit more than twice as many, and the categories
/// move into one control that shows which is active instead of showing all six
/// badly.
struct PlaylistsView: View {
    @Environment(SessionModel.self) private var session
    let onSelect: (Playlist) -> Void

    var body: some View {
        @Bindable var session = session

        ScrollView {
            LazyVStack(spacing: 0) {
                header

                if session.filteredPlaylists.isEmpty, case .ready = session.playlistLoad {
                    ContentUnavailableView(
                        "No playlists match",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different category or clear the search.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(session.filteredPlaylists) { playlist in
                        Button {
                            onSelect(playlist)
                        } label: {
                            PlaylistRow(
                                text: PlaylistRowText(
                                    playlist: playlist, currentUserID: session.user?.id
                                ),
                                artworkURL: playlist.cardImageURL
                            )
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }

                    SpotifyAttribution()
                }
            }
        }
        .background(SortifyTheme.background)
        .navigationTitle("Pick a playlist")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $session.searchText, prompt: "Filter by name")
        .refreshable { await session.loadPlaylists() }
    }

    /// Scrolls with the list rather than pinning, for the reason the tracks
    /// screen records: at the largest text sizes a fixed header taller than the
    /// screen pushes the list itself out of reach.
    @ViewBuilder
    private var header: some View {
        @Bindable var session = session

        VStack(alignment: .leading, spacing: 10) {
            categoryFilter

            // A partial list must never read as a complete one.
            if case .loading(let loaded, let total) = session.playlistLoad {
                LoadProgressRow(loaded: loaded, total: total, noun: "playlists")
            }

            if case .failed(let message) = session.playlistLoad {
                ErrorRow(message: message) {
                    Task { await session.loadPlaylists() }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One control naming the active category, not six competing for a line
    /// that fits two. A menu also gives each label the width it needs, so
    /// "Personalized" and "Collaborative" stop arriving as "Person…" and
    /// "Collab…" at every text size above the default.
    private var categoryFilter: some View {
        @Bindable var session = session

        return Menu {
            Picker("Category", selection: $session.categoryFilter) {
                ForEach(PlaylistFilter.allCases) { filter in
                    Text("\(filter.label) (\(session.count(for: filter)))").tag(filter)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(session.categoryFilter.label)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(SortifyTheme.surface, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Category")
        .accessibilityValue(session.categoryFilter.label)
        .accessibilityHint("Narrows the list to one kind of playlist.")
    }
}

// MARK: - Row

private struct PlaylistRow: View {
    let text: PlaylistRowText
    let artworkURL: URL?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(url: artworkURL)
                .frame(width: isAccessibilitySize ? 72 : 52, height: isAccessibilitySize ? 72 : 52)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(text.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(isAccessibilitySize ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                // Wraps rather than clipping: the badges are the answer to "why
                // can't I overwrite this one", so they must survive the text
                // size at which the question gets asked.
                detailLayout {
                    Text(text.trackCount)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(text.badges) { badge in
                        Label(badge.label, systemImage: badge.symbolName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
        .overlay(alignment: .bottom) {
            // Spelled out rather than `Divider()` — this row is inside a Button,
            // and a Divider takes its orientation from the stack it finds
            // itself in. See the note on the track row.
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1 / displayScale)
                .padding(.leading, 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.spoken)
        .accessibilityAddTraits(.isButton)
    }

    private var detailLayout: AnyLayout {
        isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(spacing: 8))
    }
}

// MARK: - Shared rows

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
