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

    /// The gap between two cards that have nothing to do with each other.
    ///
    /// **30, because 20 lost an argument with the rows inside the cards.** Two
    /// rows in the same card are 26pt apart (13 + 13 of `rowVertical`), so at a
    /// 20pt card gap things in *different* groups sat closer together than things
    /// in the same group - proximity arguing against the grouping the cards exist
    /// to express, with only the dotted divider left to correct it. At 30 the
    /// ratio is the right way round.
    static let cardSpacing: CGFloat = 30

    /// The gap between a card and a note or heading that belongs to it.
    ///
    /// A `SettingsExplainer` used to sit exactly `cardSpacing` from the card it
    /// describes and exactly `cardSpacing` from the unrelated card below it, so
    /// nothing but reading order said which one it belonged to. Roughly a
    /// quarter of `cardSpacing` is enough to make ownership unambiguous.
    static let attachedGap: CGFloat = 8

    static let rowSpacing: CGFloat = 14
    static let iconColumn: Double = 26
    static let rowVertical: CGFloat = 13
    /// Two-line rows take a little less, so they do not tower over their
    /// single-line siblings in the same card.
    static let twoLineRowVertical: CGFloat = 11
    /// Rows carrying a real paragraph take more.
    ///
    /// At `twoLineRowVertical` the white gap between one option's last line and
    /// the next option's title was 11 + 1 + 11 = 23pt against an intra-paragraph
    /// leading of about 18 - a ratio of 1.3, which is not enough separation for
    /// the eye to tell "next line of this" from "next option". 18 puts it at
    /// about 2:1, which is.
    static let proseRowVertical: CGFloat = 18

    /// The leading the prose on these screens is set at.
    ///
    /// Everything ran at iOS's default 1.33 line-height, which is tuned for
    /// labels and short strings. These blocks are four to eight lines long, and
    /// at that length 1.33 reads as a solid block rather than as lines. Two extra
    /// points takes the paragraph roles to about 1.5.
    static let proseLineSpacing: CGFloat = 2

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
    /// How far in from the card's content edge the dividers start.
    ///
    /// **Nil means "past the icon column", which is right only for cards whose
    /// rows have icons.** It was unconditional, and on the two screens whose rows
    /// draw no leading glyph - the FAQ, and the credential fields on the Spotify
    /// app screen - all twenty-two dotted rules floated 40pt to the right of the
    /// text they divide, aligned with nothing on the screen. A divider's whole
    /// job is to say where a row begins.
    var dividerInset: CGFloat?

    @ViewBuilder var content: Content

    /// Seeded from the same constant `SettingsRowLabel` scales, so the divider
    /// begins exactly where the row's title does at every text size. Two views
    /// each scaling one seed is the arrangement `ScreenTopBar` and
    /// `TopBarButton` already share.
    @ScaledMetric(relativeTo: .body) private var iconColumn: Double = SettingsMetrics.iconColumn

    @Environment(\.colorScheme) private var colorScheme

    private var resolvedInset: CGFloat {
        dividerInset ?? (SettingsMetrics.clamped(iconColumn) + SettingsMetrics.rowSpacing)
    }

    var body: some View {
        Group(subviews: content) { subviews in
            VStack(spacing: 0) {
                ForEach(subviews.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDottedDivider()
                            .padding(.leading, resolvedInset)
                    }
                    subviews[index]
                }
            }
        }
        .padding(.horizontal, SettingsMetrics.cardPadding)
        .background(SortyTheme.surface, in: .rect(cornerRadius: SettingsMetrics.cardRadius))
        // **The one change that makes light Appearance work.** `surface` is pure
        // white and `background` is rgb(0.957, 0.957, 0.969): about 1.09:1, which
        // is a card boundary you cannot see. Every other card-like surface in the
        // app already takes this exact shadow - `PlaylistTile` at radius 6, y 3 -
        // so settings cards were the only ones floating without elevation. Dark
        // is unaffected: `cardShadow` returns `.clear` there, because a cast
        // shadow on a near-black field is a grey smear at best.
        .shadow(color: SortyTheme.cardShadow(colorScheme), radius: 6, y: 3)
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
        // **`.firstTextBaseline`, not centred, and it only shows when a title
        // wraps.** Every title here fits one line at the default text size, where
        // the two alignments are indistinguishable. At an accessibility size they
        // are not: "Spotify Developer Dashboard" breaks onto three lines, and a
        // centred glyph then floats in the gutter beside the middle of a word,
        // labelling nothing. A leading glyph belongs beside the first line of the
        // thing it labels - which is the arrangement `SettingsSelectRow` already
        // uses for exactly this reason, on rows that always wrap.
        HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.rowSpacing) {
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
            // glyph centred against four lines of it floats in the middle of
            // nowhere - it belongs beside the title it labels.
            HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.rowSpacing) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? AnyShapeStyle(SortyTheme.accent) : AnyShapeStyle(.secondary))
                    .frame(width: SettingsMetrics.clamped(iconColumn))
                VStack(alignment: .leading, spacing: 3) {
                    // **The checkmark rides the title line rather than the whole
                    // row, and that is measure rather than decoration.** Parked
                    // in the outer stack it reserved its width down the full
                    // height of the row, so every line of the detail below was
                    // cut short by a glyph that only ever sits beside the first
                    // one. Measured: the detail column went from 269pt to 294pt,
                    // which is the difference between the ReccoBeats line
                    // breaking at 36 characters with a six-character widow and
                    // running clean to 45.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(isSelected ? AnyShapeStyle(SortyTheme.accent) : AnyShapeStyle(.primary))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SortyTheme.accent)
                            .opacity(isSelected ? 1 : 0)
                    }
                    if let detail {
                        // `.footnote`, not `.caption`. Caption is the page-note
                        // role that `SettingsExplainer` owns; setting a per-option
                        // explanation at the same size as a page footer left the
                        // screen with one grey size doing three different jobs.
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(SettingsMetrics.proseLineSpacing)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, SettingsMetrics.proseRowVertical)
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

/// A short note that belongs to the card above it without being in it.
///
/// Inset six points from the card's edge rather than flush, which is Beam's
/// arrangement and reads as a note *about* the group instead of a row that lost
/// its surface.
///
/// **`.caption` is this component's alone now, and that is what makes it mean
/// something.** It used to share the size with a select row's per-option
/// explanation, so a page-level footnote and a paragraph you had to read to make
/// a choice were set identically. The paragraph roles moved up to `.footnote`
/// and `.subheadline`; this stayed where it was and is now the smallest text on
/// the page, which is the one thing a footnote should be.
///
/// It also bonds *upward*. `SettingsScaffold` spaces its children by
/// `cardSpacing`, which put an explainer the same distance from the card it
/// describes as from the unrelated card beneath it. The negative top padding
/// pulls it back to `attachedGap`.
struct SettingsExplainer: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineSpacing(SettingsMetrics.proseLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, SettingsMetrics.attachedGap - SettingsMetrics.cardSpacing)
    }
}

/// A paragraph the listener has to read before they can decide anything.
///
/// **Distinct from `SettingsExplainer` by position, not by size.** Both are
/// secondary prose; this one sits above the card it introduces and bonds
/// *downward*, where an explainer sits below and bonds up. That is where the
/// "why" goes - a footer explaining a choice is read after the choice has been
/// made.
///
/// It was `.subheadline` for one revision, on the reasoning that a lead-in
/// naming six columns deserves more than a footnote. Measured at
/// accessibility-extra-extra-extra-large, that put nine lines of grey above the
/// card and pushed the three-way choice the screen exists for entirely off the
/// first screenful. `.footnote` is the app's one paragraph role and this is a
/// paragraph; position already says it leads.
struct SettingsLead: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineSpacing(SettingsMetrics.proseLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.bottom, SettingsMetrics.attachedGap - SettingsMetrics.cardSpacing)
    }
}

/// The label above a group of cards.
///
/// Sorty has exactly one of these - "The arrangements", on the FAQ - and until
/// now it was drawn by `SettingsExplainer`, which made the only section heading
/// in the app typographically identical to a legal disclaimer and to a six-line
/// footnote. A heading that is the smallest, faintest text on its screen is not
/// a heading.
///
/// Weight rather than size does the work, so it stays a quiet label on a screen
/// whose cards are the real structure - the grouping is still the card, which is
/// the rule these screens are built on.
struct SettingsSectionHeading: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.bottom, SettingsMetrics.attachedGap - SettingsMetrics.cardSpacing)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A callout inside a card: one glyph, one paragraph, no action.
///
/// Extracted because `AudioFeatureSettingsView` built this inline and framed its
/// icon at the raw `iconColumn` constant while every row beside it framed a
/// `@ScaledMetric` copy of the same number - so at accessibility text sizes the
/// option rows' text stepped right and the callout's did not, and the card lost
/// its left edge exactly where the text was largest. One place to scale it, next
/// to the rows it has to match.
struct SettingsNote: View {
    let icon: String
    let text: String

    @ScaledMetric(relativeTo: .body) private var iconColumn: Double = SettingsMetrics.iconColumn

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SettingsMetrics.rowSpacing) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(SortyTheme.accent)
                .frame(width: SettingsMetrics.clamped(iconColumn))
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(SettingsMetrics.proseLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, SettingsMetrics.proseRowVertical)
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
            // the first card rather than across its top edge. Tracks
            // `TopBlur.fade`, which went from 20 to 40.
            .padding(.top, 48)
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
