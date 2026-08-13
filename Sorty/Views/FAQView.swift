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
        // `dividerInset: 0` on every card here. An `FAQRow` draws no leading
        // glyph, and the card's default inset clears one - so all twenty-two
        // dotted rules on this screen used to float 40pt right of the questions
        // they divide, lined up with nothing.
        SettingsScaffold(title: FAQText.title) {
            SettingsCard(dividerInset: 0) {
                ForEach(FAQText.basics) { entry in
                    FAQRow(question: entry.question, answer: entry.answer)
                }
            }

            SettingsSectionHeading(FAQText.arrangementsHeading)

            SettingsCard(dividerInset: 0) {
                ForEach(Arrangement.Basis.allCases) { basis in
                    FAQRow(question: basis.name, answer: basis.explanation)
                }
            }

            SettingsCard(dividerInset: 0) {
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
                    // `.body`, the same as every other row title in the app. It
                    // was `.subheadline.weight(.medium)` - two points smaller
                    // than the role it plays, with the weight compensating for
                    // the size. A question is a row title; it should not be a
                    // different size here than on the four screens around it.
                    Text(question)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                }
                // **Inside the label, which is the whole of the fix.** The
                // padding used to sit on the outer `VStack`, so the button's
                // label was the bare `HStack` and the tap target was the text's
                // own height - about 22pt at the old size, half the 44pt
                // minimum. Twenty-five disclosure rows on this screen, every one
                // of them under-sized.
                .padding(.vertical, SettingsMetrics.twoLineRowVertical)
                .contentShape(.rect)
            }
            .buttonStyle(.settingsRow)

            if isOpen {
                // `.subheadline` against the question's `.body`: a 17:15 size
                // step plus a colour step, where `.footnote` gave 17:13 and read
                // as fine print rather than as the answer to the thing just
                // asked.
                Text(answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(SettingsMetrics.proseLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, SettingsMetrics.twoLineRowVertical)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(question)
        .accessibilityValue(isOpen ? answer : "")
        .accessibilityHint(isOpen ? "Collapse" : "Expand")
    }
}
