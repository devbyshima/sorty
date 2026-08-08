import SwiftUI

/// The library.
///
/// Rebuilt against `.scratch/ui-redesign-2/references/spotify-library.png`: a
/// heavy title, a row of category chips, an order control paired with a layout
/// toggle, and a three-up grid of covers. The two things the reference has that
/// Sortify has no equivalent for - a now-playing bar and a tab bar - are simply
/// absent rather than invented, because Sortify has no playback and is one
/// library rather than three destinations.
struct PlaylistsView: View {
    @Environment(SessionModel.self) private var session
    let onSelect: (Playlist) -> Void
    /// The menu lives in this screen's own header rather than in the toolbar,
    /// so these are handed in rather than reached from here.
    var onConnect: () -> Void = {}
    var onSettings: () -> Void = {}

    /// Search state lives here rather than in the bar, because the title has to
    /// know about it too.
    @State private var isSearchExpanded = false
    @State private var isSearchActive = false
    /// Measured, because the header's height changes: the title stands down
    /// while search has focus, and a fixed blur would then cover empty space.
    @State private var headerHeight: CGFloat = 120

    /// `alignment: .top` is load-bearing. Without it `GridItem` defaults to
    /// centring, and since a `LazyVGrid` row is as tall as its tallest cell,
    /// a one-line name beside a two-line one had its cover pushed *down* half
    /// the difference - so covers in the same row did not share a top edge.
    private static func gridColumns(_ count: Int) -> [GridItem] {
        [GridItem](repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: count)
    }

    var body: some View {
        @Bindable var session = session

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                loadState

                // Above the library rather than inside the Collaborative chip:
                // the chip looks empty rather than broken, and a listener who
                // never opens it would never learn why their shared playlists
                // are missing.
                if session.needsCollaborativeReconnect {
                    reconnectNotice
                }

                if session.filteredPlaylists.isEmpty, case .ready = session.playlistLoad {
                    EmptyStateView(state: .noPlaylistsMatch(hasSearch: !session.searchText.isEmpty)) {
                        session.searchText = ""
                        session.categoryFilter = .all
                    }
                    .padding(.top, 32)
                } else {
                    switch session.libraryLayout {
                    case .gridTwo, .grid:
                        grid(columns: session.libraryLayout.columns ?? 2)
                    case .list:
                        list
                    }
                }
            }
            // Longer than the blur's fade, so the ramp finishes in the gap
            // rather than on the first row of covers.
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .debugScrolled()
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(SortifyTheme.background)
        // The navigation bar is gone entirely, because neither of its title
        // modes can do what this screen needs. `.large` puts the title below
        // the button; `.inline` puts it beside the button but fixed near
        // footnote weight; and a toolbar item cannot rescue it either, since
        // iOS wraps toolbar content in a fixed glass container and clamps it -
        // measured, and it truncated "Your playlists" to "Y...".
        //
        // So the header is content: a plain row holding the title at full size
        // and the menu, which is the only arrangement where the two genuinely
        // share a line.
        .toolbar(.hidden, for: .navigationBar)
        // No `.refreshable` here, and the omission is deliberate.
        //
        // The header is a pinned `safeAreaInset`, and a pull-to-refresh gesture
        // drags *that* along with the content: the title and the whole bar
        // travel down with the pull and spring back, which reads as the header
        // wobbling every time the list is touched near the top. The two
        // features cannot share this layout.
        //
        // Refreshing is still reachable, from the menu, where it is an explicit
        // action rather than something the list does when brushed.
    }

    /// Explains an absence, and offers the only thing that fixes it.
    private var reconnectNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.2.badge.gearshape")
                .foregroundStyle(.secondary)

            Text(ReconnectNotice.collaborative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(ReconnectNotice.collaborativeAction, action: onConnect)
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(SortifyTheme.accent)
        }
        .padding(10)
        .background(SortifyTheme.surface, in: .rect(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Header

    /// Title and menu on one line, the bar under it, both pinned.
    ///
    /// The title stands down while the search field has focus, which is what
    /// gives the field the whole row rather than a corner of it.
    private var header: some View {
        @Bindable var session = session

        return VStack(alignment: .leading, spacing: 14) {
            if !isSearchActive {
                HStack(alignment: .center) {
                    Text("Your playlists")
                        .font(.largeTitle.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 8)

                    LibraryMenu(onConnect: onConnect, onSettings: onSettings)
                }
                .padding(.horizontal, 16)
            }

            LibraryBar(
                filters: PlaylistFilter.allCases,
                selection: $session.categoryFilter,
                searchText: $session.searchText,
                isSearchExpanded: $isSearchExpanded,
                onSearchActivated: { active in
                    withAnimation(.snappy) { isSearchActive = active }
                },
                count: { session.count(for: $0) }
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        // The blur is this header's *background*, so the grid passes under it
        // while the title and the chips stay sharp on top of it.
        //
        // It was an `.overlay` on the scroll view, which draws above the
        // `safeAreaInset` as well as above the content - so the blur meant to
        // hide the grid fell across "Your playlists" and smeared the one word
        // on the screen that has to be legible.
        // A short tail, matched by the content's own top padding so the ramp
        // lands on the gap below the chips instead of on artwork. At the
        // default 60 the smear reached a third of the way down the first row
        // of covers.
        .background(alignment: .top) {
            TopBlur(height: headerHeight)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
        // No background. The progressive blur behind this *is* the background,
        // and an opaque fill here would turn it into a hard-edged bar with a
        // pointless blur underneath.
    }

    // MARK: - Controls

    @ViewBuilder
    private var loadState: some View {
        if case .loading(let loaded, let total) = session.playlistLoad {
            LoadProgressRow(loaded: loaded, total: total, noun: "playlists")
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        if case .failed(let message) = session.playlistLoad {
            ErrorRow(message: message) {
                Task { await session.loadPlaylists() }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Layouts

    private func grid(columns: Int) -> some View {
        LazyVGrid(columns: Self.gridColumns(columns), alignment: .leading, spacing: 18) {
            ForEach(session.filteredPlaylists) { playlist in
                Button {
                    onSelect(playlist)
                } label: {
                    PlaylistTile(
                        text: PlaylistRowText(playlist: playlist, currentUserID: session.user?.id),
                        artwork: playlist.artworkImages,
                        owner: ownerName(for: playlist)
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(session.filteredPlaylists) { playlist in
                Button {
                    onSelect(playlist)
                } label: {
                    PlaylistRow(
                        text: PlaylistRowText(playlist: playlist, currentUserID: session.user?.id),
                        artwork: playlist.artworkImages
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ownerName(for playlist: Playlist) -> String {
        let name = playlist.owner.displayName ?? playlist.owner.id
        return name.isEmpty ? "Playlist" : name
    }
}

// MARK: - Grid tile

private struct PlaylistTile: View {
    let text: PlaylistRowText
    let artwork: [SpotifyImage]
    let owner: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverImage(images: artwork)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 6))
                .shadow(color: SortifyTheme.cardShadow(colorScheme), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                // Two lines are *reserved*, not merely allowed. A tile whose
                // name fits on one line would otherwise be shorter than its
                // neighbour, and with the row as tall as its tallest cell the
                // names in a row stopped sharing a baseline.
                Text(text.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)

                // Badges collapse to glyphs at this size: the tile has room for
                // one line, and "Collaborative" spelled out would take it all.
                // The list layout still spells them, and the spoken label below
                // always does, so nothing is lost to a VoiceOver user.
                HStack(spacing: 4) {
                    ForEach(text.badges) { badge in
                        Image(systemName: badge.symbolName)
                            .font(.caption2)
                    }
                    Text(owner)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.spoken)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - List row

private struct PlaylistRow: View {
    let text: PlaylistRowText
    let artwork: [SpotifyImage]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(images: artwork)
                .frame(width: isAccessibilitySize ? 72 : 52, height: isAccessibilitySize ? 72 : 52)
                .clipShape(.rect(cornerRadius: 6))

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
            // Spelled out rather than `Divider()` - this row is inside a Button,
            // and a Divider takes its orientation from the stack it finds
            // itself in. See the note on the track row.
            Rectangle()
                .fill(SortifyTheme.hairline)
                .frame(height: 1 / displayScale)
                .padding(.leading, 80)
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

// MARK: - Menu

/// The account, the source, and how the library is presented.
///
/// Lifted out of the toolbar so it can sit in the header row beside a
/// full-size title. Nothing about it is toolbar-specific: it is a `Menu` with a
/// glyph, and the glass container it used to inherit from the bar is drawn
/// here instead.
struct LibraryMenu: View {
    @Environment(SessionModel.self) private var session
    var onConnect: () -> Void
    var onSettings: () -> Void

    var body: some View {
        @Bindable var session = session

        Menu {
            // Which account and which source are no longer named here. They are
            // status rather than actions, and a menu is a list of things to do;
            // Settings now shows both, next to the controls that change them.
            //
            // Pickers rather than buttons, so each shows which of its options
            // is active without the menu having to say so twice.
            Picker("Sort by", selection: $session.libraryOrder) {
                ForEach(LibraryOrder.allCases) { order in
                    Label(order.label, systemImage: order.symbolName).tag(order)
                }
            }
            Picker("View as", selection: $session.libraryLayout) {
                ForEach(LibraryLayout.allCases) { layout in
                    Label(layout.label, systemImage: layout.symbolName).tag(layout)
                }
            }

            Section {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await session.loadPlaylists() }
                }
                Button("Settings", systemImage: "gearshape", action: onSettings)
                if session.isConnected {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        Task { await session.signOut() }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEdge(in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More")
    }
}
