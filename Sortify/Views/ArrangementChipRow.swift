import SwiftUI

/// The primary control: which Arrangement the playlist is in.
///
/// The composition is `ArrangementChip.row(for:)` in SortifyKit - which five are
/// pinned, that they never move, when a trailing chip appears and retires, and
/// what a tap applies. This view draws what it is handed and decides nothing.
struct ArrangementChipRow: View {
    let arrangement: Arrangement
    let onApply: (Arrangement) -> Void
    let onReroll: () -> Void
    let onMore: () -> Void

    /// `LibraryBar`'s chip animation, to the value. A slide rather than a
    /// settle: a capsule that overshoots its own edge reads as loose.
    static let selection: Animation = .interpolatingSpring(duration: 0.3, bounce: 0)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ArrangementChip.row(for: arrangement)) { chip in
                        ChipView(chip: chip, onApply: onApply, onReroll: onReroll)
                            .id(chip.id)
                    }

                    Button(action: onMore) {
                        Label("More", systemImage: "ellipsis")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .glassEdge(in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More arrangements")
                    .accessibilityHint("Opens the full list, each one explained.")
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            // The same spring `LibraryBar` gives its category chips, so applying
            // an Arrangement settles exactly the way choosing a category does.
            // Without it the accent snapped between capsules while the row one
            // screen back eased, and two rows of the same control disagreed
            // about what a selection feels like.
            .animation(Self.selection, value: arrangement)
            // Only ever scrolls for the trailing off-piste chip.
            //
            // That chip is appended past the five, so choosing (say) Valence
            // from the picker would otherwise select a chip the listener never
            // sees - the row would look as though nothing had been applied. The
            // pinned five deliberately never trigger a scroll: they are muscle
            // memory, and scrolling to reveal one would push Original order,
            // the way back, off the left edge.
            .onChange(of: arrangement.basis, initial: true) { _, basis in
                guard !ArrangementChip.pinned.contains(basis) else { return }
                proxy.scrollTo(basis.rawValue)
            }
        }
    }
}

private struct ChipView: View {
    let chip: ArrangementChip
    let onApply: (Arrangement) -> Void
    let onReroll: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(chip.basis.name)
                    .font(.subheadline.weight(chip.isActive ? .semibold : .regular))
                    .lineLimit(1)
                if let direction = chip.direction {
                    Image(systemName: direction == .ascending ? "arrow.up" : "arrow.down")
                        .font(.caption2.weight(.bold))
                }
            }
            // Still one focusable element carrying the label, the value, the
            // hint and the selected trait, for the reason the Button version
            // gave: VoiceOver has to land on the thing being described. It just
            // is not a Button any more, so it needs the trait and the action
            // spelled out.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(chip.basis.name)
            .accessibilityValue(spokenValue)
            .accessibilityHint(spokenHint)
            .accessibilityAddTraits(chip.isActive ? [.isButton, .isSelected] : [.isButton])
            .accessibilityAction { onApply(chip.tapped) }

            if chip.showsReroll {
                // Shuffle's second meaning gets its own target, so tapping the
                // chip body never means two different things. A real Button, so
                // it takes its own area out of the capsule's tap gesture.
                Button(action: onReroll) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.caption.weight(.bold))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Re-roll shuffle")
                .accessibilityHint("Draws a new random order.")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .foregroundStyle(chip.isActive ? AnyShapeStyle(SortifyTheme.onAccent) : AnyShapeStyle(.primary))
        // The same capsule the library bar uses, at the same height: glass at
        // rest, accent when applied. The two rows of chips are the same control
        // doing the same job on different nouns, so they read as one thing.
        .background(chip.isActive ? AnyShapeStyle(SortifyTheme.accent) : AnyShapeStyle(.clear), in: .capsule)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEdge(in: .capsule)
        .contentShape(.capsule)
        // The tap goes here, on the same view that carries the interactive
        // glass, which is what `LibraryBar` does and is the whole difference in
        // how the two rows felt.
        //
        // Wrapping the label in a Button instead put an interactive child
        // *inside* the glass: the child swallowed the touch, so the glass never
        // saw a press and never responded to one, and the capsule's own padding
        // was dead to the finger because only the label carried a hit shape. A
        // chip that lights up on the library screen and stays inert here is the
        // same control behaving two ways.
        .onTapGesture { onApply(chip.tapped) }
    }

    private var spokenValue: String {
        guard chip.isActive else { return "" }
        switch chip.direction {
        case .ascending: return "Applied, ascending"
        case .descending: return "Applied, descending"
        case nil: return "Applied"
        }
    }

    private var spokenHint: String {
        guard chip.isActive else { return "Arranges the playlist by \(chip.basis.name)." }
        switch chip.direction {
        case .ascending: return "Activates descending."
        case .descending: return "Activates ascending."
        case nil: return "Already applied."
        }
    }
}

// MARK: - Picker

/// Every Arrangement, each explained where it is chosen - so a listener who has
/// never met valence can pick meaningfully rather than experimentally. The copy
/// is `Basis.explanation`, the same source the FAQ reads.
struct ArrangementPickerSheet: View {
    let applied: Arrangement
    let onPick: (Arrangement) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(ArrangementChip.pickerBases) { basis in
                    Button {
                        onPick(basis.arrangement())
                        dismiss()
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(basis.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(basis.explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 8)
                            if basis == applied.basis {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(SortifyTheme.accent)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(basis == applied.basis ? [.isButton, .isSelected] : .isButton)
                    .accessibilityHint("Arranges the playlist by \(basis.name).")
                }
            }
            .navigationTitle("Arrangements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
    }
}
