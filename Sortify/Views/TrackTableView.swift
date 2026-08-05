import SwiftUI

struct TrackTableView: View {
    @State var model: TrackTableModel
    @Environment(SessionModel.self) private var session
    @Environment(\.openURL) private var openURL

    @State private var showingFilter = false
    @State private var showingSaveResult = false

    var body: some View {
        VStack(spacing: 0) {
            header

            switch model.phase {
            case .idle, .loading:
                loadingState

            case .failed(let message):
                ErrorRow(message: message) { Task { await model.load() } }
                    .padding(16)
                Spacer()

            case .empty:
                ContentUnavailableView(
                    "Nothing to sort",
                    systemImage: "music.note.list",
                    description: Text("This playlist has no playable tracks.")
                )
                Spacer()

            case .ready:
                table
            }
        }
        .background(SortifyTheme.background)
        .navigationTitle(model.playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showingFilter) {
            BPMFilterSheet(model: model)
                .presentationDetents([.height(320)])
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
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(arrangementSummary)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if model.filter.isActive {
                    Label("\(model.arrangedRows.count) shown", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SortifyTheme.accent)
                }
            }

            if let notice = model.featureNotice {
                DisclosureNotice(text: notice)
            }

            if !model.canWriteBack {
                DisclosureNotice(text: "Demo Mode is read-only — connect a Spotify account to save a sorted playlist.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var arrangementSummary: String { "Sorted by \(model.arrangement.name)" }

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

    // MARK: - Table

    /// A genuine 15-column table, scrolled horizontally rather than collapsed —
    /// the whole point of the app is comparing attributes side by side, and
    /// hiding columns behind a picker would lose that. The header pins so the
    /// column you sorted by stays visible while you scroll.
    private var table: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(model.arrangedRows.enumerated()), id: \.element.id) { index, row in
                            TrackRowView(
                                row: row,
                                isAlternate: index.isMultiple(of: 2),
                                activeBasis: model.arrangement.basis
                            )
                            .swipeActions(edge: .trailing) {
                                if let uri = row.playable.uri, let url = URL(string: uri) {
                                    Button("Open in Spotify", systemImage: "arrow.up.forward.app") {
                                        openURL(url)
                                    }
                                }
                            }
                        }
                    } header: {
                        TableHeaderRow(
                            arrangement: model.arrangement,
                            onSelect: { model.selectFromLegacyHeader($0) }
                        )
                    }
                }
                // iOS 27: swipe actions outside a List need an explicit container.
                .swipeActionsContainer()
            }
            .scrollBounceBehavior(.basedOnSize)
            // Fifteen columns are far wider than a phone. Sorting by a column
            // you then can't see is useless, so bring it into view.
            .onChange(of: model.arrangement.basis) { _, basis in
                withAnimation(.snappy) {
                    proxy.scrollTo(basis, anchor: .center)
                }
            }
            .task(id: model.phase) {
                guard model.phase == .ready, model.arrangement.basis != .originalOrder else { return }
                proxy.scrollTo(model.arrangement.basis, anchor: .center)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // iOS 27 toolbar priorities: on a narrow width the system collapses the
        // lower-priority items into the overflow menu first. Save outranks
        // Filter because a sorted-but-unsaved playlist is the dead end.
        ToolbarItem(placement: .topBarTrailing) {
            Button("Filter", systemImage: model.filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
                showingFilter = true
            }
        }
        .visibilityPriority(.low)

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
        .visibilityPriority(.high)
    }

    private var saveResultMessage: String? {
        switch model.saveStatus {
        case .created(let message), .updated(let message), .failed(let message): message
        default: nil
        }
    }
}

// MARK: - Header row

private struct TableHeaderRow: View {
    let arrangement: Arrangement
    let onSelect: (Arrangement.Basis) -> Void

    private var activeBasis: Arrangement.Basis { arrangement.basis }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Arrangement.Basis.allCases) { basis in
                Button {
                    onSelect(basis)
                } label: {
                    HStack(spacing: 3) {
                        Text(basis.legacyLabel)
                            .font(.caption.weight(activeBasis == basis ? .bold : .semibold))
                            .lineLimit(1)
                        if activeBasis == basis {
                            Image(systemName: indicator)
                                .font(.system(size: 8, weight: .bold))
                        }
                    }
                    .foregroundStyle(activeBasis == basis ? SortifyTheme.accent : .primary)
                    .frame(width: basis.legacyWidth, height: SortifyTheme.tableHeaderHeight, alignment: basis.legacyAlignment)
                    .padding(.horizontal, 6)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .id(basis)
                .accessibilityLabel(basis.name)
                .accessibilityHint(accessibilityHint(for: basis))
                .accessibilityAddTraits(activeBasis == basis ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(height: SortifyTheme.tableHeaderHeight)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    /// A directionless Arrangement has no arrow to draw — the Optional makes
    /// that a case the compiler insists on rather than a flag to remember.
    private var indicator: String {
        switch arrangement.direction {
        case .ascending: "chevron.up"
        case .descending: "chevron.down"
        case nil: "circle.fill"
        }
    }

    private func accessibilityHint(for basis: Arrangement.Basis) -> String {
        guard activeBasis == basis else { return "Sorts by \(basis.name)." }
        if basis == .shuffle { return "Reshuffles." }
        switch arrangement.direction {
        case .ascending: return "Sorted ascending. Activates descending."
        case .descending: return "Sorted descending. Activates ascending."
        case nil: return "Already sorted by \(basis.name)."
        }
    }
}

// MARK: - Data row

private struct TrackRowView: View {
    let row: TrackRow
    let isAlternate: Bool
    let activeBasis: Arrangement.Basis

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Arrangement.Basis.allCases) { basis in
                let value = row.legacyCellText(for: basis)
                Text(value.isEmpty ? "—" : value)
                    .font(font(for: basis))
                    .foregroundStyle(foreground(for: basis, isEmpty: value.isEmpty))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .tabularNumbers()
                    .frame(width: basis.legacyWidth, height: SortifyTheme.tableRowHeight, alignment: basis.legacyAlignment)
                    .padding(.horizontal, 6)
                    .background(activeBasis == basis ? SortifyTheme.accent.opacity(0.09) : .clear)
            }
        }
        .frame(height: SortifyTheme.tableRowHeight)
        .background(SortifyTheme.rowFill(isAlternate: isAlternate))
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func font(for basis: Arrangement.Basis) -> Font {
        if basis == .attribute(.title) { return .footnote.weight(row.playable.isEpisode ? .regular : .medium) }
        return .footnote
    }

    private func foreground(for basis: Arrangement.Basis, isEmpty: Bool) -> Color {
        if isEmpty { return .secondary.opacity(0.5) }
        if row.playable.isEpisode && (basis == .attribute(.title) || basis == .attribute(.artist)) { return .secondary }
        return basis == activeBasis ? .primary : .primary.opacity(0.85)
    }

    /// One spoken sentence per row: position, what it is, and the value the
    /// active Arrangement ordered by — reading all fifteen cells aloud would be
    /// unusable.
    private var accessibilityLabel: String {
        var parts = ["\(row.originalIndex + 1).", row.playable.name]
        if let artist = row.playable.primaryArtistName {
            parts.append("by \(artist)")
        } else if row.playable.isEpisode {
            parts.append("podcast episode")
        }
        // Position, title and artist are already spoken above, so repeating
        // them as "the value sorted by" would say the same thing twice.
        if activeBasis != .attribute(.order), activeBasis != .attribute(.title), activeBasis != .attribute(.artist) {
            let value = row.legacyCellText(for: activeBasis)
            parts.append("\(activeBasis.name) \(value.isEmpty ? "unavailable" : value)")
        }
        return parts.joined(separator: " ")
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
                    .lineLimit(expanded ? nil : 2)
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
    @Bindable var model: TrackTableModel
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
