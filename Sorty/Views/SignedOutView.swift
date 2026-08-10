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
///
/// **The cost is no longer named on this screen.** A line of small print under
/// the button used to say that Spotify requires each listener to register a free
/// developer app. It has gone, and the first connect step still opens on exactly
/// that - so the fact arrives one tap later than it did rather than not at all,
/// which is the trade this screen makes for a clean foot.
///
/// Rebuilt on Beam's onboarding (ADR-0016): the three points cycle through a
/// reel rather than sitting in a list, over the same bloom the splash rises
/// from, so launch and way-in read as one screen continuing rather than two.
struct SignedOutView: View {
    var onConnect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// Three, and each one a thing Sorty does rather than a thing it has.
    private let points = [
        OnboardingReel.Phase(
            symbol: "slider.horizontal.3",
            title: "Arrange by how it sounds",
            body: "Tempo, energy, mood. Put a playlist in an order the music itself decides."
        ),
        OnboardingReel.Phase(
            symbol: "person.2",
            title: "Spread out repeated artists",
            body: "Or shuffle properly. Both are arrangements, one tap away."
        ),
        OnboardingReel.Phase(
            symbol: "square.and.arrow.down",
            title: "Save it back to Spotify",
            body: "Overwrite the playlist, or keep the original and save a new one."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if reduceMotion {
                stillPoints
            } else {
                OnboardingReel(phases: points)
                    .opacity(appeared ? 1 : 0)
            }

            connect
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // `.background`, never a ZStack sibling. The backdrop's circle is far
        // wider than the screen, and as a sibling it sizes the stack - which
        // proposed every text child a width past both edges and clipped the
        // value props and the small print. A background never drives layout.
        .background { SplashBackdrop() }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.smooth(duration: 0.5)) { appeared = true }
        }
    }

    // MARK: - Reduced

    /// What the reel says, said all at once and holding still.
    ///
    /// Not a degraded reel - a reel with its animation removed is three lines of
    /// text replacing each other on a timer, which is still movement and still
    /// hides two thirds of the content behind a wait. The list was this screen's
    /// original design and it remains the right answer for anyone who has asked
    /// for less motion.
    private var stillPoints: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            SortyMarkTile(side: 88)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 20) {
                ForEach(points) { point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.symbol)
                            .font(.title3)
                            .foregroundStyle(SortyTheme.accent)
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

            Spacer(minLength: 24)
        }
    }

    // MARK: - The action

    /// The foot every other onboarding screen is levelled against.
    ///
    /// It looks the same as it always did, and is now written the same way the
    /// connect flow's is: one `OnboardingButton`, `buttonBottom` beneath it, and
    /// nothing else in the foot. The four steps used to draw a glass button of
    /// their own at a different height over a deeper foot, which is what put
    /// them off this screen's line.
    private var connect: some View {
        Button(action: onConnect) {
            Text("Connect Spotify")
        }
        .buttonStyle(OnboardingButton())
        .accessibilityHint("Starts the four steps for connecting your Spotify account.")
        .padding(.horizontal, 24)
        .padding(.bottom, OnboardingMetrics.buttonBottom)
    }
}
