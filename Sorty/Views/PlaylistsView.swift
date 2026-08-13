import SwiftUI

/// The library.
///
/// Rebuilt against `.scratch/ui-redesign-2/references/spotify-library.png`: a
/// heavy title, a row of category chips, an order control paired with a layout
/// toggle, and a three-up grid of covers. The two things the reference has that
/// Sorty has no equivalent for - a now-playing bar and a tab bar - are simply
/// absent rather than invented, because Sorty has no playback and is one
/// library rather than three destinations.
struct PlaylistsView: View {
    @Environment(SessionModel.self) private var session
    let onSelect: (Playlist) -> Void
    /// The menu lives in this screen's own header rather than in the toolbar,
    /// so this is handed in rather than reached from here.
    var onSettings: () -> Void = {}
    /// The namespace the zoom into a playlist is matched in.
    ///
    /// Handed in rather than declared here, for the reason `RootView` gives
    /// where it declares it: the destination side of the pair is built in the
    /// `navigationDestination` closure, which cannot see a namespace that lives
    /// in this view.
    let zoomNamespace: Namespace.ID

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
            // A plain stack, and it has to be.
            //
            // This was a `LazyVStack`, which bought nothing - `grid` is a
            // `LazyVGrid` and `list` is a `LazyVStack` of its own, so the rows
            // were already lazy and this only wrapped them. What it cost was an
            // *estimated* content extent while its later children were
            // unmeasured, and the estimate overshoots once the footer holds a
            // paragraph that wraps: scrolling to the bottom landed past the end
            // of the content and `32-playlists-attribution`, whose whole job is
            // to prove Spotify's mark still renders, came back empty.
            VStack(alignment: .leading, spacing: 0) {
                loadState

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

                    withheldNotice

                    // Required wherever Spotify's metadata is shown, and every
                    // playlist name and cover above is exactly that. Inside the
                    // `else` because the requirement attaches to the metadata:
                    // there is none to attribute while the library is loading,
                    // failing, or filtered down to nothing.
                    //
                    // **Last, and the notice above it goes above it for that
                    // reason.** The mark is the one element here that is not a
                    // design choice, and `32-playlists-attribution` reaches it
                    // by scrolling to the bottom - so anything added below it
                    // takes its place in the one shot that exists to prove it
                    // still renders. It was silently lost once already.
                    SpotifyAttribution()
                }

                // The placeholders above are each hidden from VoiceOver, so
                // without this a library still filling is silent - a heading and
                // then nothing, which is indistinguishable from an empty one.
                // One element carries the one true thing, and it is a status
                // rather than content: no value, no action, and it disappears
                // when the rows it stands for arrive.
                if trailingPlaceholders > 0 {
                    Color.clear
                        .frame(height: 1)
                        .accessibilityElement()
                        .accessibilityLabel("Loading more playlists")
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            // Longer than the blur's fade, so the ramp finishes in the gap
            // rather than on the first row of covers. Tracks `TopBlur.fade`,
            // which went from 20 to 40.
            .padding(.top, 48)
            .padding(.bottom, 24)
        }
        .debugScrolled()
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(SortyTheme.background)
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

    /// How many playlists Spotify listed and would not name.
    ///
    /// **At the foot, and quiet.** It names a rule with no remedy - no
    /// permission grants it, no button helps - and a permanent unactionable
    /// banner over the library is precisely the thing `EmptyState`'s own rules
    /// argue against. Here it is found by the person who went looking for the
    /// playlist that isn't there, and invisible to everyone else.
    ///
    /// Directly above `SpotifyAttribution`, never below it: the mark has to be
    /// the last thing on the screen, because it is the one element here that is
    /// mandatory rather than chosen and the shot that proves it renders finds it
    /// by scrolling to the bottom. ADR-0018.
    @ViewBuilder
    private var withheldNotice: some View {
        if let notice = LibraryNotice.withheldFromListing(count: session.withheldPlaylistCount) {
            Text(notice)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        }
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

                    LibraryMenu(onSettings: onSettings)
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
        // Lighter here than anywhere else, which is the one place the app breaks
        // its own "every screen blurs alike" rule and does it knowingly.
        //
        // This header has more passing under it than any other: a grid of large
        // covers, edge to edge, moving fast. Everywhere else the bar backs a
        // single cover and some text. The same radius that reads as separation
        // on the playlist screen reads as a smear across artwork here, because
        // there is simply more artwork to smear. The *fade* is still shared, so
        // content still lets go at one rate across the app; only the strength
        // differs, and only on the screen that needed it.
        .background(alignment: .top) {
            // Eight points shorter than the header that owns it, which is the
            // one number here not derived from a measurement.
            //
            // The solid region used to run the header's full height, so the band
            // ended level with the bottom of the header's own padding and read
            // taller than the chrome it was backing. Trimming it lets the fade
            // start just under the chips instead. Eight and not more: the
            // header's bottom padding is ten, so this leaves two points of solid
            // below the chip row, and anything larger would put the chips
            // themselves over a fading backdrop with rows showing through them.
            //
            // It only makes the content below *more* clear of the ramp, so the
            // grid's own top padding still lands the fade in the gap.
            TopBlur(height: max(0, headerHeight - 8), maxBlur: 1.5)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
        // No background. The progressive blur behind this *is* the background,
        // and an opaque fill here would turn it into a hard-edged bar with a
        // pointless blur underneath.
    }

    // MARK: - Controls

    /// How many placeholders trail the playlists already in hand.
    ///
    /// **Trailing only, never a screenful**, and that is the part of ADR-0015
    /// this keeps: the grid genuinely does fill, batch by batch, so the part
    /// that has arrived needs no explaining. What 0015 never covered is the part
    /// that hasn't - a two-up grid showing three of forty-seven playlists is not
    /// a library filling, it is a library that looks finished and is wrong.
    ///
    /// Zero once every page has landed, and zero before the first one: at that
    /// point the splash is still over this screen (ADR-0019), and drawing a grid
    /// of shapes nobody can see costs a layout pass for nothing.
    private var trailingPlaceholders: Int {
        guard case .loading(let loaded, let total) = session.playlistLoad else { return 0 }
        // Only while the library is unfiltered. A search matching two playlists
        // is not waiting for forty more, and shapes under it would promise
        // results that are never coming.
        guard session.searchText.isEmpty, session.categoryFilter == .all else { return 0 }
        return SkeletonPlan.trailingCount(
            loaded: loaded,
            total: total,
            columns: session.libraryLayout.columns ?? 1
        )
    }

    @ViewBuilder
    /// Failures only. **Loading still shows no status** - see the placeholders
    /// above, which are shape rather than status.
    ///
    /// There was a counting row here, "Loaded 12 of 40 playlists…" over a
    /// determinate bar. It was accurate and it was noise: the number is not
    /// actionable, nobody waits differently for knowing it, and it made an
    /// ordinary two-second fetch look like an operation with a status. A
    /// failure still speaks, because that one *is* actionable.
    ///
    /// ADR-0019 gives the count a second job and not that one: `loaded`/`total`
    /// now decides *how many shapes to draw* and is still printed nowhere.
    private var loadState: some View {
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
                        owner: ownerName(for: playlist),
                        zoomID: playlist.id,
                        zoomNamespace: zoomNamespace
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.pressableRow)
            }

            ForEach(0..<trailingPlaceholders, id: \.self) { index in
                PlaylistTilePlaceholder(index: index)
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
                        artwork: playlist.artworkImages,
                        zoomID: playlist.id,
                        zoomNamespace: zoomNamespace
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.pressableRow)
            }

            ForEach(0..<trailingPlaceholders, id: \.self) { index in
                PlaylistRowPlaceholder(index: index)
            }
        }
    }

    private func ownerName(for playlist: Playlist) -> String {
        let name = playlist.owner.displayName ?? playlist.owner.id
        return name.isEmpty ? "Playlist" : name
    }
}

/// The corner every playlist cover is cut to, in both layouts.
///
/// A constant rather than four literals because a fifth place now reads it: the
/// zoom's `matchedTransitionSource` carries this radius into the transition, so
/// a change here that missed the transition would show up as the artwork
/// changing shape for half a second on its way to opening.
enum PlaylistArtwork {
    static let radius: CGFloat = 6
}

extension View {
    /// Marks a playlist's cover as the thing its screen grows out of.
    ///
    /// **On the artwork, not on the row that contains it.** The first version
    /// put this on the whole button - cover, name and owner - on the reasoning
    /// that the zoom should start from what the finger hit. What that produced
    /// was a portrait rectangle of mostly text unfolding into a screen, and the
    /// one element the two screens genuinely share went along for the ride.
    /// The track list opens on this same artwork, large and centred; growing the
    /// screen out of the cover makes the transition a statement about *this
    /// playlist* rather than about a cell.
    ///
    /// The clip shape is the cover's own corner, carried into the transition, so
    /// the artwork does not change shape on its way there. It reads
    /// `PlaylistArtwork.radius` rather than repeating 6 for that reason.
    func playlistZoomSource(id: String, in namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id, in: namespace) { source in
            source.clipShape(.rect(cornerRadius: PlaylistArtwork.radius))
        }
    }
}

// MARK: - Grid tile

private struct PlaylistTile: View {
    let text: PlaylistRowText
    let artwork: [SpotifyImage]
    let owner: String
    let zoomID: String
    let zoomNamespace: Namespace.ID

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverImage(images: artwork)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: PlaylistArtwork.radius))
                .playlistZoomSource(id: zoomID, in: zoomNamespace)
                .shadow(color: SortyTheme.cardShadow(colorScheme), radius: 6, y: 3)

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

                // Badges collapse to glyphs at this size: the tile has one line
                // and shares it with the owner's name. The list layout still
                // spells them, and the spoken label below always does, so
                // nothing is lost to a VoiceOver user.
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

// MARK: - Placeholders

/// A tile that hasn't arrived, at exactly the geometry of one that has.
///
/// Every number here is `PlaylistTile`'s, and that is the whole design
/// constraint: the two are photographed side by side and nothing may move
/// between them. The square cover with its 6pt radius, the 8pt gap, the two
/// reserved name lines, the 2pt gap and the `.caption2` detail line.
///
/// The cover is `CoverShimmer` rather than a `SkeletonShape`, because a cover
/// waiting for its file is a state this app already had a placeholder for and
/// one idiom is better than two.
private struct PlaylistTilePlaceholder: View {
    let index: Int

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverShimmer(phase: SkeletonPlan.phase(at: index, period: CoverShimmer.cycle))
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: PlaylistArtwork.radius))
                .shadow(color: SortyTheme.cardShadow(colorScheme), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                // Two lines reserved, matching the tile's own
                // `lineLimit(2, reservesSpace: true)`. A one-line placeholder
                // would let every tile in the row jump when the names land.
                VStack(alignment: .leading, spacing: 2) {
                    SkeletonLine(font: .footnote.weight(.semibold), widthFraction: 0.92, index: index)
                    SkeletonLine(font: .footnote.weight(.semibold), widthFraction: 0.55, index: index + 1)
                }
                SkeletonLine(font: .caption2, widthFraction: 0.42, index: index + 2)
            }
        }
    }
}

/// A list row that hasn't arrived, at exactly the geometry of one that has.
private struct PlaylistRowPlaceholder: View {
    let index: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var side: CGFloat { dynamicTypeSize.isAccessibilitySize ? 72 : 52 }

    var body: some View {
        HStack(spacing: 12) {
            CoverShimmer(phase: SkeletonPlan.phase(at: index, period: CoverShimmer.cycle))
                .frame(width: side, height: side)
                .clipShape(.rect(cornerRadius: PlaylistArtwork.radius))

            VStack(alignment: .leading, spacing: 3) {
                SkeletonLine(font: .subheadline.weight(.medium), widthFraction: 0.66, index: index)
                SkeletonLine(font: .caption, widthFraction: 0.28, index: index + 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // No chevron. It is not content that is loading, it is an
            // affordance for a row that cannot be tapped yet, and drawing one
            // over a placeholder invites the tap.
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
    }
}

// MARK: - List row

private struct PlaylistRow: View {
    let text: PlaylistRowText
    let artwork: [SpotifyImage]
    let zoomID: String
    let zoomNamespace: Namespace.ID

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(images: artwork)
                .frame(width: isAccessibilitySize ? 72 : 52, height: isAccessibilitySize ? 72 : 52)
                .clipShape(.rect(cornerRadius: PlaylistArtwork.radius))
                .playlistZoomSource(id: zoomID, in: zoomNamespace)

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
                .fill(SortyTheme.hairline)
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
                // Signing out moved into Settings, which is where the account it
                // ends is now named. It was an account action sitting among
                // library actions, and it was the only destructive thing in a
                // menu you open to change how a grid is sorted.
                Button("Settings", systemImage: "gearshape", action: onSettings)
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
