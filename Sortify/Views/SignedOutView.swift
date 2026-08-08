import SwiftUI

/// The way in, and the whole of the app until an account is connected.
///
/// ADR-0003 made Demo Mode the front door and this screen a once-only welcome
/// whose primary action led into a sample library. ADR-0007 removed Demo Mode,
/// so there is nothing to explore into and no reason to show this once: it is
/// the state, not a moment. It appears whenever there is no account - a first
/// run, a sign-out, tokens that no longer work - and disappears the instant one
/// connects.
///
/// It is a gate, and says so. The three points are here because the connect
/// flow opens on the five-listener cap and never gets round to what the app is
/// for, and asking someone to register a developer application before telling
/// them that is the wrong order.

struct SignedOutView: View {
    var onConnect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private struct Point: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let body: String
    }

    /// Three, and each one a thing Sortify does rather than a thing it has.
    private let points = [
        Point(
            symbol: "slider.horizontal.3",
            title: "Arrange by how it sounds",
            body: "Tempo, energy, mood. Put a playlist in an order the music itself decides."
        ),
        Point(
            symbol: "person.2",
            title: "Spread out repeated artists",
            body: "Or shuffle properly. Both are arrangements, one tap away."
        ),
        Point(
            symbol: "square.and.arrow.down",
            title: "Save it back to Spotify",
            body: "Overwrite the playlist, or keep the original and save a new one."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            SortifyMarkTile(side: 88)
                .scaleEffect(shown ? 1 : 0.9)
                .opacity(shown ? 1 : 0)
                .padding(.bottom, 22)

            VStack(spacing: 8) {
                Text("Sortify")
                    .font(.largeTitle.bold())
                Text("Reorder a Spotify playlist by the character of its music.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 34)
            .opacity(shown ? 1 : 0)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(points) { point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.symbol)
                            .font(.title3)
                            .foregroundStyle(SortifyTheme.accent)
                            .frame(width: 30)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(point.title)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(point.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 32)
            .opacity(shown ? 1 : 0)

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button(action: onConnect) {
                    Text("Connect Spotify")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(SortifyTheme.accent, in: .capsule)
                        .foregroundStyle(SortifyTheme.onAccent)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Starts the four steps for connecting your Spotify account.")

                // Says the cost up front rather than letting it arrive at step
                // two. Spotify caps a development-mode application at five
                // listeners, so a shared Client ID would lock out every user
                // past the fifth - which is why this cannot be a plain sign-in
                // and why the flow has four steps instead of one.
                Text("Spotify needs you to register a free developer application and paste its Client ID. The steps walk you through it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SortifyTheme.background)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.snappy(duration: 0.5)) { appeared = true }
        }
    }

    /// Reduced Motion gets the finished state immediately rather than a faded
    /// one: the animation carries no information, so removing it must remove
    /// only the movement.
    private var shown: Bool { appeared || reduceMotion }
}
