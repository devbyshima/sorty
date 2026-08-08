import SwiftUI

/// One playlist, in the order the active Arrangement puts it.
///
/// Rebuilt against `.scratch/ui-redesign-2/references/spotify-playlist.png`:
/// the cover leads, then the name, then what the playlist is, then the action
/// that matters, then the chips, then the tracks.
///
/// Two deliberate departures from the reference, both forced:
///
/// - **The anchor action is Save, not play.** Sortify has no playback. Save is
///   this screen's entire purpose, so it takes the position the reference gives
///   the play button, in the app's own accent rather than Spotify's green
///   (ADR-0006).
/// - **Nothing is drawn on the artwork.** Spotify's guidelines forbid overlaying
///   text or images on their artwork, and their own screen may do it because it
///   is theirs. The name sits beneath the cover here.
struct TrackListView: View {
    @State var model: TrackListModel
    /// Reaching for Save without an account opens the connect flow rather than
    /// meeting a disabled control.
    var onConnect: () -> Void = {}
    @Environment(SessionModel.self) private var session
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    /// The bar draws its own back button now that the system one is hidden.
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilter = false
    @State private var showingPicker = false
    @State private var showingSaveResult = false
    /// The track whose detail sheet is open. A `TrackRow` rather than an index:
    /// the list it came from is rebuilt whenever the Arrangement changes, and
    /// an index into it would then point at a different song.
    @State private var inspecting: TrackRow?
    /// One diameter, always.
    ///
    /// It used to be the measured height of the whole identity block, which made
    /// it a function of how long the playlist's *description* was - and worse, a
    /// loop: a bigger circle narrowed the text column, which wrapped onto more
    /// lines, which measured taller, which grew the circle again. 56 was the
    /// floor that measurement produced; 48 is smaller still, and now that the
    /// armed state colours the whole material it no longer needs the size to
    /// carry the emphasis.
    @ScaledMetric(relativeTo: .title) private var saveDiameter: Double = 48
    /// The cover-and-identity block above the chip row, measured so the row's
    /// pinned state can be derived from the scroll offset rather than guessed.
    @State private var headerHeight: CGFloat = 0
    /// True once the chip row has reached the top and stuck. It decides which
    /// half of the blur owns the fade, so the two never overlap.
    @State private var chipsPinned = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Matches `TopBarButton`, which the back chevron beside it uses.
    @ScaledMetric(relativeTo: .headline) private var scaledMenuSide: Double = TopBarMetrics.side

    /// Applying an Arrangement, watched rather than merely arrived at.
    ///
    /// Whether to animate at all is `ReorderAnimation.animates` in SortifyKit:
    /// a measured row limit and the Reduced Motion rule, neither of which is a
    /// layout question.
    private func rearrange(_ change: () -> Void) {
        guard ReorderAnimation.animates(rowCount: model.rows.count, reduceMotion: reduceMotion) else {
            change()
            return
        }
        withAnimation(.snappy) { change() }
    }

    var body: some View {
        ScrollView {
            // The chip row is a pinned section header: it scrolls up with the
            // cover, then sticks. The primary control must not scroll out of
            // reach on the screen whose whole purpose is applying it, and the
            // reference's own header scrolls away entirely.
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }

                Section {
                    content
                } header: {
                    // Nothing to arrange on a playlist Spotify will not open, so
                    // the row of things to arrange it by is not offered. It read
                    // as a screen still deciding, above a sentence that had
                    // already decided.
                    if isOpenable {
                        ArrangementChipRow(
                            arrangement: model.arrangement,
                            onApply: { arrangement in rearrange { model.apply(arrangement) } },
                            onReroll: { rearrange { model.reroll() } },
                            onMore: { showingPicker = true }
                        )
                        .padding(.vertical, 10)
                        // **Only while pinned.** At its resting position the row
                        // is ordinary content with ordinary content above and
                        // below it, and a blur there has nothing to hide - it
                        // would just haze the chips and smear what sits directly
                        // beneath them, before the listener has touched anything.
                        //
                        // Once pinned it becomes the bottom half of a single band
                        // that starts at the screen edge: solid for the row's own
                        // 58pt, with the 40pt tail below as the only fade in the
                        // pair. The default overscan matters here - it carries the
                        // solid region *up under the bar*, so where the two meet
                        // there is solid blur on solid blur and no hairline of
                        // unblurred content between them. The bar clips its own
                        // background while pinned so it contributes nothing below
                        // its edge; without that the bar's tail ramped 1 to 0 on
                        // top of this one's solid region and the composite stepped
                        // from double strength to single in a single pixel row,
                        // which is the seam that was visible just above the chips.
                        .background(alignment: .top) {
                            if chipsPinned {
                                TopBlur(height: 58)
                            }
                        }
                    }
                }
            }
            .swipeActionsContainer()
        }
        // The row pins when the cover and identity above it have scrolled out,
        // which is exactly when the offset passes the header's own height.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            headerHeight > 0 && geometry.contentOffset.y + geometry.contentInsets.top >= headerHeight
        } action: { _, pinned in
            chipsPinned = pinned
        }
        .debugScrolled()
        .scrollBounceBehavior(.basedOnSize)
        .background(SortifyTheme.background)
        // The bar owns the blur, the way the library screen's header does.
        //
        // While the chip row is pinned the bar draws no blur of its own: the
        // row's band overscans up past this and backs both, so the whole header
        // is one even surface. Unpinned there is nothing below to continue it,
        // so it keeps its own 40pt tail for the cover to pass through.
        .safeAreaInset(edge: .top, spacing: 0) {
            ScreenTopBar(
                title: model.playlist.name,
                showsBlur: !chipsPinned
            ) {
                TopBarButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            } trailing: {
                overflowMenu
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingPicker) {
            ArrangementPickerSheet(applied: model.arrangement) { arrangement in
                rearrange { model.apply(arrangement) }
            }
        }
        .sheet(isPresented: $showingFilter) {
            BPMFilterSheet(model: model)
                .presentationDetents([.height(320)])
        }
        .sheet(item: $inspecting) { row in
            TrackDetailSheet(detail: model.detail(for: row))
        }
        .alert("Save", isPresented: $showingSaveResult) {
            Button("OK") { model.clearSaveStatus() }
        } message: {
            Text(saveResultMessage ?? "")
        }
        .onChange(of: model.saveStatus) { _, status in
            switch status {
            case .created, .updated, .failed: showingSaveResult = true
            default: break
            }
        }
        .task {
            await model.load()
            if let arrangement = DebugLaunch.arrangement {
                model.apply(arrangement)
            }
            if let filter = DebugLaunch.filter {
                model.filter = filter
            }
            switch DebugLaunch.sheet {
            case .arrangements: showingPicker = true
            case .filter: showingFilter = true
            case .track:
                // Counted in what's on screen, so the harness can name the
                // unrankable ones too.
                let position = DebugLaunch.trackPosition ?? 0
                let rows = model.arrangedRows
                if rows.indices.contains(position) { inspecting = rows[position] }
            case nil: break
            }
        }
    }

    // MARK: - Header

    /// False for a playlist Spotify answers about but never opens (ADR-0008).
    /// Everything on this screen that offers to *do* something reads from this:
    /// there is no list to arrange and nothing to save, and controls that stay
    /// behind to be disabled are a screen arguing with itself.
    private var isOpenable: Bool {
        if case .unavailable = model.phase { return false }
        return true
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            identity
        }
        .padding(.bottom, 4)
    }

    /// Centred, square, and given real margin. Nothing is drawn on top of it:
    /// Spotify's design guidelines forbid overlaying their artwork, which is
    /// why the name sits below rather than across the bottom of the image.
    ///
    /// The same sticker behaviour the track sheet's cover has, and the same
    /// size-aware artwork resolution: at 260pt on a 3x display this asks for
    /// 780 pixels and gets the 640 file, where the old accessor handed it 300.
    private var cover: some View {
        StickerCover(images: model.playlist.artworkImages, cornerRadius: 8)
            .frame(maxWidth: 260)
            .shadow(color: SortifyTheme.cardShadow(colorScheme), radius: 18, y: 10)
            .frame(maxWidth: .infinity, alignment: .center)
            // Clearance for the blur, not decoration. The fade under the
            // navigation bar needs somewhere to finish: at 8pt the cover began
            // inside it, so the tail had to be cut short enough to read as a
            // hard-edged grey box sliding over the artwork instead of a fade.
            // This is the room that lets the tail be long enough to disappear.
            .padding(.top, 52)
            .padding(.bottom, 20)
            .accessibilityHidden(true)
    }

    /// The name, and Save beside it.
    ///
    /// There is no strip of controls under this any more. The filter and the
    /// arrangement picker both live in the overflow menu, which is where a
    /// secondary action belongs once the primary one has a home: two grey
    /// glyphs floating between the title and the chips read as a third band of
    /// chrome on a screen that already had too many, and neither was the thing
    /// anyone came here to press.
    ///
    /// Save moves up to sit with the name because that is the pairing that
    /// means something: *this playlist*, and the one thing you can do to it.
    private var identity: some View {
        identityLayout {
            identityText
                .frame(maxWidth: .infinity, alignment: .leading)

            // Save is the one thing you can do to a playlist, and on one Spotify
            // will not open there is nothing to do it to. A dimmed circle there
            // is a control explaining itself; leaving it out says the same thing
            // and asks for nothing.
            if isOpenable {
                saveAnchor
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var identityText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.playlist.name)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)

            if let description = model.playlist.rawDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(subtitleLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Side by side normally, stacked once the text is large enough that a
    /// title sharing its line would wrap to a column two words wide.
    ///
    /// Side by side, the two are the same height: the button stretches to the
    /// text block rather than floating at a fixed size in the middle of it, so
    /// the pair reads as one unit with a shared top and bottom edge.
    private var identityLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    /// Owner, then how much there is of it. Both are what the reference puts
    /// here, and both are things Sortify actually knows.
    private var subtitleLine: String {
        let owner = model.playlist.owner.displayName ?? model.playlist.owner.id
        // Nothing loaded and nothing reported. Spotify sends no count for a
        // playlist it will not open, and "0 tracks" here would be the header
        // filling that gap with a number it does not have.
        guard model.playlist.trackCountIsKnown || !model.rows.isEmpty else {
            return owner.isEmpty
                ? PlaylistRowText.hiddenTrackCount
                : "\(owner) · \(PlaylistRowText.hiddenTrackCount)"
        }
        let count = model.rows.isEmpty ? model.playlist.tracks.total : model.rows.count
        // An active filter had exactly one indicator, and it was on the strip
        // of controls that has just been removed. Said here instead, because a
        // list quietly showing a third of a playlist with nothing explaining
        // why is the kind of thing people report as lost tracks.
        let tracks = model.filter.isActive
            ? "\(model.arrangedRows.count) of \(count) tracks"
            : (count == 1 ? "1 track" : "\(count) tracks")
        return owner.isEmpty ? tracks : "\(owner) · \(tracks)"
    }

    /// Which actions appear, what they say and whether each is armed are all
    /// `SaveAction` in SortifyKit - ADR-0002's split is a rule about what each
    /// one may write, and a button is no place to keep a rule like that.
    ///
    /// **Genuine Liquid Glass, not a tinted circle.** Two earlier attempts were
    /// not the material at all. `.glassEffect(.regular.tint(...))` applied by
    /// hand, over a flat background and under a strong tint, collapses into a
    /// solid disc: no specular edge, no refraction, none of what makes glass
    /// read as glass. `.glassProminent` is no better here for the same reason -
    /// it is the *filled* variant, opaque by design, and tinting it just paints
    /// the disc a different way.
    ///
    /// `.glass` is the translucent one, and it is the one that actually
    /// refracts what sits behind it and picks up a specular edge.
    /// `GlassEffectContainer` lets it sample its surroundings properly. The
    /// size is a hand-set square rather than a platform control metric, because
    /// the circle has to agree with the cover above it rather than with a
    /// system button - see `saveDiameter`.
    ///
    /// **Armed is a tinted material, not a tinted glyph.** The accent used to
    /// live on the mark inside clear glass, which said "this is available" in
    /// about as quiet a voice as the screen has - on the one control the screen
    /// exists for. `.regular.tint(...)` keeps the refraction and the specular
    /// edge and colours the material itself, so armed and unarmed differ by the
    /// whole button rather than by a glyph.
    @ViewBuilder
    private var saveAnchor: some View {
        GlassEffectContainer {
            if !model.canWriteBack {
                // No account. Not disabled and not an error: the way forward.
                Button(action: onConnect) { saveGlyph(isArmed: true) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save")
                    .accessibilityHint("Saving needs a connected Spotify account. Opens the steps for connecting one.")
            } else {
                Menu {
                    ForEach(model.saveActions) { action in
                        Button(
                            action.title,
                            systemImage: action.kind == .overwrite
                                ? "arrow.down.to.line"
                                : "plus.rectangle.on.folder",
                            role: action.kind == .overwrite ? .destructive : nil
                        ) {
                            Task { await model.perform(action.kind) }
                        }
                        .disabled(!action.isEnabled)
                    }
                } label: {
                    saveGlyph(isArmed: model.canSave)
                }
                .buttonStyle(.plain)
                .disabled(!model.canSave)
                .accessibilityLabel("Save")
            }
        }
    }

    /// **Why this glyph.** `square.and.arrow.down`, the obvious choice, does not
    /// sit right in a circle: the arrow's tail extends above the square, so the
    /// symbol's layout box is taller than its ink. SwiftUI centres the box, which
    /// leaves the ink low and reading as misaligned. `arrow.down.to.line` is
    /// symmetric on both axes with nothing overhanging, so centring the box
    /// centres the mark, and "commit this down to a destination" is what Save
    /// does here.
    ///
    /// **Why the material is applied here rather than by a button style.**
    /// `.buttonStyle(.glass)` draws genuine Liquid Glass but sizes itself from
    /// its label plus padding of its own, which cannot be asked for an exact
    /// diameter, so the material goes on directly.
    ///
    /// The spinner is swapped in place, so the circle keeps its size while
    /// saving and nothing on the screen shifts.
    private func saveGlyph(isArmed: Bool) -> some View {
        ZStack {
            if model.saveStatus == .saving {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.down.to.line")
                    .font(.title3.weight(.semibold))
                    // On tinted glass the mark is the accent's foreground; on
                    // clear glass there is nothing to sit on, so it stays quiet.
                    .foregroundStyle(isArmed ? AnyShapeStyle(SortifyTheme.onAccent) : AnyShapeStyle(.secondary))
            }
        }
        // Square, so the capsule the glass is drawn in is a true circle.
        .frame(width: saveDiameter, height: saveDiameter)
        .glassEffect(
            isArmed
                ? .regular.tint(SortifyTheme.accent).interactive()
                : .regular.interactive(),
            in: .circle
        )
        .contentShape(.circle)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .loading:
            loadingState

        case .failed(let message):
            // No Try Again where trying again cannot work: a rule that refused
            // this request will refuse the next one identically, and a button
            // that only ever reproduces the same refusal is worse than none.
            ErrorRow(
                message: message,
                retry: model.canRetryLoad ? { Task { await model.load() } } : nil
            )
            .padding(16)

        case .empty:
            EmptyStateView(state: .playlistEmpty)
                .padding(.top, 40)

        case .unavailable(let state):
            // A rule, not a failure, so it gets the empty-state treatment and
            // the way out the state names: Spotify, where this playlist can be
            // opened and its tracks added to one of the listener's own.
            EmptyStateView(state: state) {
                if let url = URL(string: model.playlist.uri) { openURL(url) }
            }
            .padding(.top, 40)

        case .ready:
            if model.arrangedRows.isEmpty, model.filter.isActive {
                EmptyStateView(state: .filterHidesEverything(total: model.rows.count)) {
                    model.filter = BPMFilter(includeDoubled: model.filter.includeDoubled)
                }
                .padding(.top, 40)
            } else {
                list
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            if case .loading(let loaded, let total) = model.phase {
                Text(total > 0 ? "Loaded \(loaded) of \(total) tracks…" : "Loading tracks…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            if !model.canWriteBack {
                DisclosureNotice(text: "Connect a Spotify account to save an arrangement.")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            ForEach(Array(model.rankedRows.enumerated()), id: \.element.id) { position, row in
                trackRow(row, position: position + 1)
            }

            // What the Arrangement couldn't place, said out loud.
            ForEach(model.unrankableGroups) { group in
                UnrankableGroupHeader(group: group)

                ForEach(group.rows) { row in
                    trackRow(row, position: nil)
                }
            }

        }
        .padding(.bottom, 24)
    }

    /// Unrankable rows are passed no position: they have no place in the
    /// arrangement, and numbering them would imply one.
    private func trackRow(_ row: TrackRow, position: Int?) -> some View {
        Button {
            inspecting = row
        } label: {
            TrackListRow(
                row: row,
                position: position,
                arrangement: model.arrangement,
                range: model.positionRange
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // The row already speaks as one sentence; this only says what happens
        // if you activate it.
        .accessibilityHint("Opens every attribute for this track.")
        .swipeActions(edge: .trailing) {
            if let url = row.spotifyURL {
                Button("Open on Spotify", systemImage: "arrow.up.forward.app") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - Toolbar

    /// The bar no longer carries Save: the anchor in the header does. What is
    /// left is secondary by definition.
    private var overflowMenu: some View {
        Menu {
            // Both act on a list. Where there is none, the link out is the whole
            // of what this menu can honestly offer, and it is also the way out
            // the screen itself names.
            if isOpenable {
                Button("All arrangements", systemImage: "slider.horizontal.3") {
                    showingPicker = true
                }
                Button("Tempo filter", systemImage: "line.3.horizontal.decrease.circle") {
                    showingFilter = true
                }
            }
            if let url = URL(string: model.playlist.uri) {
                if isOpenable { Divider() }
                Button("Open on Spotify", systemImage: "arrow.up.forward.app") {
                    openURL(url)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .frame(width: TopBarMetrics.clamped(scaledMenuSide), height: TopBarMetrics.clamped(scaledMenuSide))
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(.circle)
        }
        // Without this the menu takes the automatic style, which tints its own
        // label with the accent and applies its own press transform - so the
        // trailing control was indigo and reactive while the leading one was
        // primary and inert, on a bar where they are meant to be a pair.
        .buttonStyle(.plain)
        .accessibilityLabel("More")
    }

    private var saveResultMessage: String? {
        switch model.saveStatus {
        case .created(let message), .updated(let message), .failed(let message): message
        default: nil
        }
    }
}

// MARK: - Row

private struct TrackListRow: View {
    let row: TrackRow
    let position: Int?
    let arrangement: Arrangement
    /// The playlist's span for the active Attribute, or nil when this
    /// Arrangement has no bar to draw.
    let range: AttributeRange?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Every word on the row, decided in SortifyKit where it is tested.
    private var text: TrackRowText {
        TrackRowText(row: row, position: position, arrangement: arrangement)
    }

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isAccessibilitySize {
                // At accessibility sizes there is no room for artwork, two
                // lines of text and a value side by side - squeezing them
                // truncates the title, which is the one thing this screen
                // exists to keep.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        artwork
                        Spacer(minLength: 8)
                        valueLabel
                    }
                    titleAndArtist
                }
            } else {
                HStack(spacing: 12) {
                    artwork
                    titleAndArtist
                    Spacer(minLength: 8)
                    valueLabel
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.spoken)
    }

    /// Artwork grows with the text so it doesn't shrink into a dot beside
    /// accessibility-sized titles.
    private var artwork: some View {
        CoverImage(images: row.playable.coverImages)
            .frame(width: isAccessibilitySize ? 60 : 44, height: isAccessibilitySize ? 60 : 44)
            .clipShape(.rect(cornerRadius: 4))
    }

    private var titleAndArtist: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(row.playable.isEpisode ? .secondary : .primary)
                .lineLimit(isAccessibilitySize ? 4 : 1)
                .fixedSize(horizontal: false, vertical: true)

            Text(text.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The value, and under it the bar placing that value among the others.
    /// A track the provider had nothing for gets neither: an absent measurement
    /// must not look like a low one.
    @ViewBuilder
    private var valueLabel: some View {
        if let value = text.value {
            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SortifyTheme.accent)
                    .lineLimit(1)

                if let fraction = range?.fraction(for: row) {
                    PositionBar(fraction: fraction)
                }
            }
        }
    }
}

// MARK: - Notice

struct DisclosureNotice: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    // Two lines of accessibility-sized text is barely a
                    // sentence, so the collapsed form gets more room.
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(SortifyTheme.surface, in: .rect(cornerRadius: 10))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BPM filter

private struct BPMFilterSheet: View {
    @Bindable var model: TrackListModel
    @Environment(\.dismiss) private var dismiss

    @State private var minText = ""
    @State private var maxText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Minimum") {
                        TextField("0", text: $minText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    LabeledContent("Maximum") {
                        TextField("1000", text: $maxText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Toggle("Include doubled BPM", isOn: $model.filter.includeDoubled)
                } header: {
                    Text("Tempo range")
                } footer: {
                    Text("A 70 BPM track and a 140 BPM track often feel like the same tempo, and detectors routinely halve one or double the other. With this on, a track also matches when twice its BPM lands in range.\n\nTracks with no BPM always stay visible, including episodes and anything the feature source missed.")
                }

                Section {
                    LabeledContent("Showing", value: "\(model.arrangedRows.count) of \(model.rows.count)")
                    if model.hiddenRowCount > 0 {
                        LabeledContent("Hidden", value: "\(model.hiddenRowCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("BPM Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        minText = ""
                        maxText = ""
                        model.filter = BPMFilter(includeDoubled: model.filter.includeDoubled)
                    }
                    .disabled(!model.filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
            .onAppear {
                minText = model.filter.minBPM.map(String.init) ?? ""
                maxText = model.filter.maxBPM.map(String.init) ?? ""
            }
            .onChange(of: minText) { _, new in model.filter.minBPM = Int(new) }
            .onChange(of: maxText) { _, new in model.filter.maxBPM = Int(new) }
        }
    }
}
