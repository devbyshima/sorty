import SwiftUI

/// The FAQ.
///
/// A page on the same scaffold as Settings, which is where it is reached from.
/// It was the app's other stock-chrome screen - a `List` of `DisclosureGroup`s
/// inside its own `NavigationStack` inside a sheet - and it was presented from
/// two places at once, from the settings sheet and from the root, so it could
/// open on top of itself.
///
/// Its Credits section is gone, promoted to `CreditsView`. Naming who Sorty is
/// a port of at the bottom of the fourteenth collapsed question was not
/// crediting anybody.
struct FAQView: View {
    var body: some View {
        SettingsScaffold(title: FAQText.title) {
            SettingsCard {
                ForEach(FAQText.basics) { entry in
                    FAQRow(question: entry.question, answer: entry.answer)
                }
            }

            SettingsExplainer(FAQText.arrangementsHeading)

            SettingsCard {
                ForEach(Arrangement.Basis.allCases) { basis in
                    FAQRow(question: basis.name, answer: basis.explanation)
                }
            }

            SettingsCard {
                ForEach(FAQText.limits) { entry in
                    FAQRow(question: entry.question, answer: entry.answer)
                }
            }
        }
    }
}

/// One question, and its answer when asked for.
///
/// A hand-built disclosure rather than `DisclosureGroup`, which draws its own
/// chevron in its own place and insists on `List`'s insets - both of which fight
/// a card that owns its padding and its dividers.
private struct FAQRow: View {
    let question: String
    let answer: String

    @State private var isOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack(spacing: SettingsMetrics.rowSpacing) {
                    Text(question)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.settingsRow)

            if isOpen {
                Text(answer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, SettingsMetrics.twoLineRowVertical)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(question)
        .accessibilityValue(isOpen ? answer : "")
        .accessibilityHint(isOpen ? "Collapse" : "Expand")
    }
}
