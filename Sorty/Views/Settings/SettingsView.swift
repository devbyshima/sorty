import SwiftUI

/// Settings.
///
/// **A page, not a sheet, and that is the whole of the redesign.** It was a
/// `Form` inside its own `NavigationStack` inside a `.sheet`, which made it one
/// of only two screens in Sorty wearing stock chrome and the only one that could
/// not push. Everything below follows from being able to push: the long Form
/// became a short page over three sub-pages, the Credits stopped being a
/// footnote at the bottom of the FAQ and became a destination, and the close
/// button became a back chevron.
///
/// The card-and-dotted-divider arrangement is Beam's, in Sorty's tokens and
/// Sorty's system font. What it buys over `Form` is that the grouping is the
/// card: no screen here has a single uppercase section header on it.
struct SettingsView: View {
    @Environment(SessionModel.self) private var session
    let onConnect: () -> Void

    /// The same key `RootView` applies, so changing it here changes the whole
    /// app rather than this screen.
    @AppStorage("appearance") private var appearance: AppearanceChoice = .system
    @State private var confirmingSignOut = false

    var body: some View {
        SettingsScaffold(title: SettingsText.title, largeTitle: true) {
            accountCard

            // **One card, where Appearance had its own.** A card that groups
            // nothing is a row wearing a background, and it cost a full card gap
            // to say so. All three of these are things you set and all three
            // carry a trailing value, which is the only test a card here has to
            // pass. Sign out keeps its own card, and is the one single-row card
            // that earns it: it is the only destructive thing on the page.
            SettingsCard {
                appearanceRow
                navigationRow(
                    icon: "key",
                    title: SettingsText.spotifyApp,
                    route: .spotifyApp
                ) {
                    if session.configuration.clientID.trimmingCharacters(in: .whitespaces).isEmpty {
                        SettingsValue(text: SettingsText.spotifyAppUnset, isUnset: true)
                    }
                }
                navigationRow(
                    icon: session.configuration.featureSource.symbolName,
                    title: SettingsText.audioFeatures,
                    route: .audioFeatures
                ) {
                    SettingsValue(text: session.configuration.featureSource.label)
                }
            }

            SettingsCard {
                navigationRow(icon: "questionmark.circle", title: SettingsText.faq, route: .faq) { EmptyView() }
                navigationRow(icon: "heart.text.square", title: SettingsText.credits, route: .credits) { EmptyView() }
            }

            if session.isConnected {
                SettingsCard {
                    signOutRow
                }
            }

            footer
        }
        .confirmationDialog(
            SettingsText.signOutConfirmTitle,
            isPresented: $confirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(SettingsText.signOut, role: .destructive) {
                Task { await session.signOut() }
            }
        } message: {
            Text(SettingsText.signOutConfirmDetail)
        }
    }

    // MARK: - Account

    /// The head of the page, and the one card that is not `surface`.
    ///
    /// The accent as a field rather than as an assertion (`SortyTheme.accentWash`)
    /// is what makes it read as a header rather than as the first row of a
    /// group. Beam's `proCard` does the same job with the same move; there is no
    /// Pro here, so what it states is which account the rest of the page is
    /// about - which is the question Settings could not answer while signing out
    /// lived in the library's menu.
    private var accountCard: some View {
        Group {
            if session.isConnected {
                accountCardBody {
                    Text(SettingsText.accountConnected)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(action: onConnect) {
                    accountCardBody {
                        Text(SettingsText.accountNotConnected)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.settingsRow)
            }
        }
    }

    private func accountCardBody(@ViewBuilder detail: () -> some View) -> some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(SettingsText.account(
                    displayName: session.user?.displayName,
                    id: session.user?.id
                ))
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                detail()
            }
            Spacer(minLength: 8)
            if !session.isConnected {
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(SortyTheme.onAccent)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(SortyTheme.accent))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SortyTheme.accentWash, in: .rect(cornerRadius: SettingsMetrics.headerCardRadius))
    }

    /// Spotify's own avatar where the account has one, and the mark otherwise.
    ///
    /// `CoverImage` rather than an `AsyncImage`, so a face loads through the same
    /// measure-then-choose-file path every cover in the app uses and waits behind
    /// the same placeholder.
    @ViewBuilder
    private var avatar: some View {
        let side: CGFloat = 46
        if let images = session.user?.images, !images.isEmpty {
            CoverImage(images: images)
                .frame(width: side, height: side)
                .clipShape(.circle)
        } else {
            Image(systemName: session.isConnected ? "person.fill" : "link")
                .font(.title3)
                .foregroundStyle(SortyTheme.accent)
                .frame(width: side, height: side)
                .background(Circle().fill(SortyTheme.accent.opacity(0.18)))
        }
    }

    // MARK: - Rows

    /// The row whose glyph *is* its value, so it answers what it is set to
    /// without being read. Beam's move, and the only row on the page with
    /// nowhere to hang a trailing value.
    /// **The whole row is the menu's label, not the value at the end of it.**
    ///
    /// The `Menu` used to wrap only its own `HStack` of text and chevron, which
    /// is an unpadded ~22pt target against the 44pt minimum - and
    /// `SettingsRowLabel`'s own `.contentShape(.rect)` was decorative here,
    /// because nothing wrapped the row in a button at all. Tapping the word
    /// "Appearance", or its glyph, or the gap between them did nothing; only the
    /// word "System" worked. Now the row behaves like every other row on the
    /// page, at its full height, with the same press response.
    private var appearanceRow: some View {
        Menu {
            Picker(SettingsText.appearance, selection: $appearance) {
                ForEach(AppearanceChoice.allCases) { choice in
                    Label(choice.label, systemImage: choice.symbolName).tag(choice)
                }
            }
        } label: {
            SettingsRowLabel(icon: appearance.symbolName, title: SettingsText.appearance) {
                HStack(spacing: 4) {
                    Text(appearance.label)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.settingsRow)
    }

    /// `NavigationLink(value:)` rather than a `Button` that appends to a path:
    /// every destination is registered on the stack's root in `RootView`, so a
    /// push from here needs to know nothing about the stack it is in.
    private func navigationRow(
        icon: String,
        title: String,
        route: LibraryRoute,
        @ViewBuilder value: () -> some View
    ) -> some View {
        NavigationLink(value: route) {
            SettingsRowLabel(icon: icon, title: title) {
                HStack(spacing: 8) {
                    value()
                    SettingsChevron()
                }
            }
        }
        .buttonStyle(.settingsRow)
    }

    private var signOutRow: some View {
        Button {
            confirmingSignOut = true
        } label: {
            SettingsRowLabel(icon: "rectangle.portrait.and.arrow.right", title: SettingsText.signOut) {
                EmptyView()
            }
            .foregroundStyle(SortyTheme.destructive)
        }
        .buttonStyle(.settingsRow)
    }

    // MARK: - Footer

    /// Container-less, which is what keeps it from reading as one more setting.
    private var footer: some View {
        VStack(spacing: 4) {
            Text(SettingsText.madeBy)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(SettingsText.version(
                short: Bundle.main.shortVersion,
                build: Bundle.main.buildVersion
            ))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }
}

extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var buildVersion: String? {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}
