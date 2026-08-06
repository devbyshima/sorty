import SwiftUI

/// The primary control: which Arrangement the playlist is in.
///
/// The composition is `ArrangementChip.row(for:)` in SortifyKit — which five are
/// pinned, that they never move, when a trailing chip appears and retires, and
/// what a tap applies. This view draws what it is handed and decides nothing.
struct ArrangementChipRow: View {
    let arrangement: Arrangement
    let onApply: (Arrangement) -> Void
    let onReroll: () -> Void
    let onMore: () -> Void

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
                            .padding(.vertical, 8)
                            .background(SortifyTheme.surface, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More arrangements")
                    .accessibilityHint("Opens the full list, each one explained.")
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            // Only ever scrolls for the trailing off-piste chip.
            //
            // That chip is appended past the five, so choosing (say) Valence
            // from the picker would otherwise select a chip the listener never
            // sees — the row would look as though nothing had been applied. The
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
            Button {
                onApply(chip.tapped)
            } label: {
                HStack(spacing: 4) {
                    Text(chip.basis.name)
                        .font(.subheadline.weight(chip.isActive ? .semibold : .regular))
                        .lineLimit(1)
                    if let direction = chip.direction {
                        Image(systemName: direction == .ascending ? "arrow.up" : "arrow.down")
                            .font(.caption2.weight(.bold))
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            // On the Button, not on a container around it: VoiceOver focuses
            // the button, and a `.contain` element above it would keep the
            // label, the selected trait and the hint away from the thing being
            // read out.
            .accessibilityLabel(chip.basis.name)
            .accessibilityValue(spokenValue)
            .accessibilityHint(spokenHint)
            .accessibilityAddTraits(chip.isActive ? [.isSelected] : [])

            if chip.showsReroll {
                // Shuffle's second meaning gets its own target, so tapping the
                // chip body never means two different things.
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
        .padding(.vertical, 8)
        .foregroundStyle(chip.isActive ? AnyShapeStyle(SortifyTheme.onAccent) : AnyShapeStyle(.primary))
        .background(
            chip.isActive ? AnyShapeStyle(SortifyTheme.accent) : AnyShapeStyle(SortifyTheme.surface),
            in: .capsule
        )
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

/// Every Arrangement, each explained where it is chosen — so a listener who has
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
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
