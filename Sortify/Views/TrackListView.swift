import SwiftUI

/// One playlist, in the order the active Arrangement puts it.
///
/// The fifteen-column table this replaces is described in ADR-0001: it summed to
/// roughly 1,352pt against a 402pt screen, and centring the column you sorted by
/// pushed title and artist off the left edge, so the screen carrying the app's
/// whole value stopped saying which track each row was. Here identity is never
/// scrolled away — a row is artwork, title, artist, and the one number the
/// Arrangement actually ordered by.
struct TrackListView: View {
    @State var model: TrackListModel
    @Environment(SessionModel.self) private var session
    @Environment(\.openURL) private var openURL

    @State private var showingFilter = false
    @State private var showingPicker = false
    @State private var showingSaveResult = false
    /// The track whose detail sheet is open. A `TrackRow` rather than an index:
    /// the list it came from is rebuilt whenever the Arrangement changes, and
    /// an index into it would then point at a different song.
    @State private var inspecting: TrackRow?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Side by side normally; stacked once the text is large enough that both
    /// would otherwise truncate.
    private var summaryLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 10))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Only the chip row is pinned. Everything else — the summary, the
            // filter, the notices — scrolls with the list, because at the
            // largest text sizes a fixed header taller than the screen would
            // push the list itself out of reach entirely.
            ArrangementChipRow(
                arrangement: model.arrangement,
                onApply: { model.apply($0) },
                onReroll: { model.reroll() },
                onMore: { showingPicker = true }
            )
            .padding(.vertical, 10)

            switch model.phase {
            case .idle, .loading:
                loadingState

            case .failed(let message):
                ErrorRow(message: message) { Task { await model.load() } }
                    .padding(16)
                Spacer()

            case .empty:
                ContentUnavailableView(
                    "Nothing to arrange",
                    systemImage: "music.note.list",
                    description: Text("This playlist has no playable tracks.")
                )
                Spacer()

            case .ready:
                list
            }
        }
        .background(SortifyTheme.background)
        .navigationTitle(model.playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { saveButton }
        .sheet(isPresented: $showingPicker) {
            ArrangementPickerSheet(applied: model.arrangement) { model.apply($0) }
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
                // unrankable ones too — they sit past the ranked tracks in
                // exactly this list.
                let position = DebugLaunch.trackPosition ?? 0
                let rows = model.arrangedRows
                if rows.indices.contains(position) { inspecting = rows[position] }
            case nil: break
            }
        }
    }

    // MARK: - Header

    /// Scrolls with the list — see the note at the top of `body`.
    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The active chip already shows *which*; this says it in words,
            // because an arrow is a poor way to learn that "descending" means
            // slowest last. `Arrangement.name` is written to slot into a
            // sentence ("increasing BPM"), so it gets one.
            //
            // Stacks at accessibility sizes rather than competing with the
            // filter for a line that fits neither.
            summaryLayout {
                Text("Arranged by \(model.arrangement.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                filterButton
            }
            .padding(.horizontal, 16)

            if !model.canWriteBack {
                DisclosureNotice(text: "Demo Mode is read-only — connect a Spotify account to save an arrangement.")
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tempo filter lives in the screen rather than the toolbar, because the
    /// navigation bar holds Save alone: a produced-but-unsaved arrangement is
    /// this screen's dead end, and nothing may compete with the way out of it.
    private var filterButton: some View {
        Button {
            showingFilter = true
        } label: {
            Label(
                model.filter.isActive ? "\(model.arrangedRows.count) of \(model.rows.count)" : "Filter",
                systemImage: model.filter.isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .font(.subheadline)
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.filter.isActive ? AnyShapeStyle(SortifyTheme.accent) : AnyShapeStyle(.secondary))
        .accessibilityLabel(
            model.filter.isActive
                ? "Tempo filter, showing \(model.arrangedRows.count) of \(model.rows.count) tracks"
                : "Tempo filter, off"
        )
        .accessibilityHint("Narrows the list to a tempo range.")
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView().controlSize(.large)
            if case .loading(let loaded, let total) = model.phase {
                Text(total > 0 ? "Loaded \(loaded) of \(total) tracks…" : "Loading tracks…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                listHeader

                ForEach(Array(model.rankedRows.enumerated()), id: \.element.id) { position, row in
                    trackRow(row, position: position + 1)
                }

                // What the Arrangement couldn't place, said out loud. These
                // used to sink here anyway, showing a dash and no reason.
                ForEach(model.unrankableGroups) { group in
                    UnrankableGroupHeader(group: group)

                    ForEach(group.rows) { row in
                        trackRow(row, position: nil)
                    }
                }
            }
            // iOS 27: swipe actions outside a List need an explicit container.
            .swipeActionsContainer()
        }
        .scrollBounceBehavior(.basedOnSize)
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
        // if you activate it, which is the one thing the sentence can't cover.
        .accessibilityHint("Opens every attribute for this track.")
        .swipeActions(edge: .trailing) {
            if let url = row.spotifyURL {
                Button("Open in Spotify", systemImage: "arrow.up.forward.app") {
                    openURL(url)
                }
            }
        }
    }

    // MARK: - Toolbar

    /// Save, and nothing else. Everything the old toolbar also held has moved
    /// into the screen.
    @ToolbarContentBuilder
    private var saveButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Save as New Playlist", systemImage: "plus.rectangle.on.folder") {
                    Task { await model.save(createNew: true) }
                }
                if model.canOverwrite {
                    Button("Overwrite This Playlist", systemImage: "square.and.arrow.down", role: .destructive) {
                        Task { await model.save(createNew: false) }
                    }
                }
            } label: {
                if model.saveStatus == .saving {
                    ProgressView()
                } else {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
            }
            .disabled(!model.canSave)
        }
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
    @Environment(\.displayScale) private var displayScale

    /// Every word on the row, decided in SortifyKit where it is tested.
    private var text: TrackRowText {
        TrackRowText(row: row, position: position, arrangement: arrangement)
    }

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if isAccessibilitySize {
                // At accessibility sizes there is no room for artwork, two
                // lines of text and a value side by side — squeezing them
                // truncates the title, which is the one thing this screen
                // exists to keep. So the row reflows: identifiers on one line,
                // then the title and artist with the full width to themselves.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        positionLabel
                        artwork
                        Spacer(minLength: 8)
                        valueLabel
                    }
                    titleAndArtist
                }
            } else {
                HStack(spacing: 12) {
                    positionLabel
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
        .overlay(alignment: .bottom) {
            // Spelled out rather than `Divider()`, which takes its orientation
            // from the stack it finds itself in. The row is a Button now, and a
            // Button lays its label out horizontally, which silently turned
            // every row separator into one continuous vertical line down the
            // middle of the list.
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1 / displayScale)
                .padding(.leading, 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.spoken)
    }

    /// Keeps its width when there is no number, so artwork and titles stay in
    /// one column across the ranked tracks and the groups below them.
    private var positionLabel: some View {
        Text(text.position ?? "")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
            .frame(minWidth: 24, alignment: .trailing)
    }

    /// Artwork grows with the text so it doesn't shrink into a dot beside
    /// accessibility-sized titles.
    private var artwork: some View {
        CoverImage(url: row.playable.coverImageURL)
            .frame(width: isAccessibilitySize ? 60 : 44, height: isAccessibilitySize ? 60 : 44)
            .clipShape(.rect(cornerRadius: 6))
    }

    private var titleAndArtist: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(row.playable.isEpisode ? .secondary : .primary)
                .lineLimit(isAccessibilitySize ? 4 : 2)
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
    /// A track the provider had nothing for gets neither — an absent
    /// measurement must not look like a low one.
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
                    // Without this the text is offered a single line's height
                    // and truncates instead of wrapping into the room it has.
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
                    Text("A 70 BPM track and a 140 BPM track often feel like the same tempo, and detectors routinely halve one or double the other. With this on, a track also matches when twice its BPM lands in range.\n\nTracks with no BPM — episodes, or anything the feature source missed — always stay visible.")
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
                    Button("Done") { dismiss() }.fontWeight(.semibold)
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
