import SwiftUI

// MARK: - Metrics

/// The numbers these screens are built on, in one place.
///
/// Beam's, with one change: the icon column scales with Dynamic Type and the
/// divider's inset is derived from it, where Beam hard-codes both. Sorty ships
/// five screenshots at accessibility sizes and a fixed 26pt column does not
/// contain a `.body` glyph at any of them - it bleeds into the title beside it.
enum SettingsMetrics {
    /// The page's own margin.
    ///
    /// Wider than the 16 the library and playlist screens use, because a card
    /// spends 16 more inside itself: at 16 and 16 the text in a card would line
    /// up exactly with the title above it and the card would stop reading as an
    /// object sitting on a field.
    static let pageMargin: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 20
    /// One step rounder, for the accent card at the head of the page.
    static let headerCardRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 20
    static let rowSpacing: CGFloat = 14
    static let iconColumn: Double = 26
    static let rowVertical: CGFloat = 13
    /// Two-line rows take a little less, so they do not tower over their
    /// single-line siblings in the same card.
    static let twoLineRowVertical: CGFloat = 11

    /// Unclamped, a `.body` glyph at the largest accessibility size takes the
    /// column past 60pt and leaves the title nowhere to be. Same reasoning, and
    /// the same shape, as `TopBarMetrics.clamped`.
    static func clamped(_ scaled: Double) -> CGFloat { min(scaled, 44) }
}

// MARK: - Card

/// A group of settings rows on one surface.
///
/// Ported from Beam's `SettingsCard`, in Sorty's tokens. **The grouping is the
/// card**: there is not one uppercase section header anywhere on these screens,
/// which is what lets a page of settings read as a short stack of objects rather
/// than as a form with eight headings. It is the single biggest reason these
/// screens stopped looking like `Form`.
///
/// `Group(subviews:)` rather than a `VStack` the caller separates by hand, so a
/// row cannot be added without its divider: the separators are this type's
/// business and no call site gets to decide how much of one it wants.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    /// Seeded from the same constant `SettingsRowLabel` scales, so the divider
    /// begins exactly where the row's title does at every text size. Two views
    /// each scaling one seed is the arrangement `ScreenTopBar` and
    /// `TopBarButton` already share.
    @ScaledMetric(relativeTo: .body) private var iconColumn: Double = SettingsMetrics.iconColumn

    var body: some View {
        Group(subviews: content) { subviews in
            VStack(spacing: 0) {
                ForEach(subviews.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDottedDivider()
                            .padding(.leading, SettingsMetrics.clamped(iconColumn) + SettingsMetrics.rowSpacing)
                    }
                    subviews[index]
                }
            }
        }
        .padding(.horizontal, SettingsMetrics.cardPadding)
        .background(SortyTheme.surface, in: .rect(cornerRadius: SettingsMetrics.cardRadius))
    }
}

/// The line between two rows in a card.
///
/// Dotted rather than solid, which is Beam's and is the one mannerism these
/// screens borrow wholesale. `lineWidth` is a full point rather than a hairline:
/// the dashes already cost the line most of its ink, and a sub-pixel dotted rule
/// is not a quieter divider, it is an absent one. Same reason it draws
/// `SortyTheme.dottedSeparator` rather than `hairline`.
struct SettingsDottedDivider: View {
    var color: Color = SortyTheme.dottedSeparator

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1.5, 5]))
            .foregroundStyle(color)
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - Rows

/// One row's content: a muted icon, a title, and a trailing accessory.
struct SettingsRowLabel<Trailing: View>: View {
    let icon: String
    let title: String
    var dimmed = false
    @ViewBuilder var trailing: Trailing

    @ScaledMetric(relativeTo: .body) private var iconColumn: Double = SettingsMetrics.iconColumn

    var body: some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: SettingsMetrics.clamped(iconColumn))
            Text(title)
                .font(.body)
                .foregroundStyle(dimmed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, SettingsMetrics.rowVertical)
        .contentShape(.rect)
    }
}

/// A row that leads somewhere else in this app.
struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

/// A row that leaves the app.
///
/// A different glyph from `SettingsChevron` on purpose: a chevron promises
/// another Sorty screen with a way back, and this one promises Safari.
struct SettingsExternalIcon: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

/// The trailing value on a navigation row.
///
/// Load-bearing rather than decorative: it is what makes it acceptable to put a
/// setting behind a push at all. Without it the root page hides the two settings
/// most likely to be wrong, and a listener whose Client ID is unset has to open
/// a sub-page to discover it.
struct SettingsValue: View {
    let text: String
    var isUnset = false

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isUnset ? AnyShapeStyle(SortyTheme.accent) : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

/// A row that picks one of a set, in the shape Beam's storage settings use.
///
/// Checkmarks rather than a `Picker`, because each option carries a sentence
/// explaining it - `FeatureSourceMode.explanation` is the only place in the app
/// that says why an audio-feature source has to be chosen - and a segmented
/// control has nowhere to put one.
struct SettingsSelectRow: View {
    let icon: String
    let title: String
    let detail: String?
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconColumn: Double = SettingsMetrics.iconColumn

    var body: some View {
        Button(action: action) {
            // Top-aligned, not centred. These rows carry a paragraph, and a
            // glyph centred against five lines of it floats in the middle of
            // nowhere - it belongs beside the title it labels. The checkmark
            // goes with it, so the row's two ends agree.
            HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.rowSpacing) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? AnyShapeStyle(SortyTheme.accent) : AnyShapeStyle(.secondary))
                    .frame(width: SettingsMetrics.clamped(iconColumn))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SortyTheme.accent)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.vertical, SettingsMetrics.twoLineRowVertical)
            .contentShape(.rect)
        }
        .buttonStyle(.settingsRow)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Press response

/// What a settings row does under a finger.
///
/// **Opacity, not scale.** `.pressableRow` takes a row to 0.97, which is right
/// for a playlist row standing alone on the background and wrong for one inside
/// a card: it shrinks the row away from the dividers drawn at its own edges, so
/// the card appears to come apart for the length of a tap.
///
/// Reduce Motion needs no branch. There is no motion here to reduce - a change
/// of opacity is already the reduced form of every other press response in this
/// app, which is the same argument `RootView` makes about its cross-fades.
struct SettingsRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == SettingsRowStyle {
    static var settingsRow: SettingsRowStyle { SettingsRowStyle() }
}

// MARK: - Prose

/// A paragraph that belongs to the card above it without being in it.
///
/// Inset six points from the card's edge rather than flush, which is Beam's
/// arrangement and reads as a note *about* the group instead of a row that lost
/// its surface.
struct SettingsExplainer: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

// MARK: - Scaffolding

/// The chrome every settings screen shares.
///
/// One scroll view, one set of margins, and the app's own progressive blur
/// behind a bar this screen owns - rather than a `Form` inside a stock
/// `NavigationStack`, which is what made Settings and the FAQ the two screens
/// that did not look like the rest of Sorty.
///
/// `largeTitle` is the root page's arrangement: the back control and the title
/// share a line, the way `PlaylistsView` shares one between its title and its
/// menu. Sub-pages take the inline `ScreenTopBar` that `TrackListView` uses, so
/// depth is legible from the chrome alone.
struct SettingsScaffold<Content: View>: View {
    let title: String
    var largeTitle = false
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss
    @State private var headerHeight: CGFloat = 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.cardSpacing) {
                content
            }
            .padding(.horizontal, SettingsMetrics.pageMargin)
            // Longer than the blur's fade, so the ramp finishes in the gap above
            // the first card rather than across its top edge.
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .debugScrolled()
        .scrollBounceBehavior(.basedOnSize)
        .background(SortyTheme.background)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var header: some View {
        if largeTitle {
            HStack(spacing: 12) {
                TopBarButton(systemImage: "chevron.left", label: "Back") { dismiss() }
                Text(title)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            .background(alignment: .top) {
                TopBlur(height: headerHeight)
            }
        } else {
            ScreenTopBar(title: title) {
                TopBarButton(systemImage: "chevron.left", label: "Back") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
    }
}
