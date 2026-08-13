import SwiftUI

/// The shape of something that hasn't arrived.
///
/// Sorty already had one of these - `CoverShimmer`, which stands in for a cover
/// while its file is on the way. This is the same idea for everything that is
/// not square: a name, an artist, a count. **Cover-shaped placeholders keep
/// using `CoverShimmer`** and nothing here touches them, which also keeps every
/// shader in the app on the same side of the compliance boundary ADR-0015 drew.
///
/// **A shader and a shimmer, both of which ADR-0019 ruled out.** ADR-0020
/// reverses it; what follows is what changed and what did not.
///
/// The geometric objection is gone. `coverRipple`'s rings were genuinely
/// square-specific - it took `length(uv - 0.5)`, so on a 140x12 bar they
/// stretched into extreme ellipses - but `coverShimmer` is a band along
/// `(uv.x + uv.y) * 0.5`, which on that same bar flattens into a sweep from one
/// end to the other. It is the shape a bar wants.
///
/// The silent-failure objection stands and is answered rather than dismissed: a
/// `[[stitchable]]` function that fails to resolve is skipped and SwiftUI draws
/// the unmodified view, which here is a flat grey bar - indistinguishable from
/// success in a still. `44-playlists-pending` and `45-tracks-pending` are that
/// guard, and they now have to be read as *motion* shots: a still frame of a
/// sweep is a bar with a bright region somewhere along it, and a bar with no
/// bright region anywhere is the failure.
///
/// What does not change is the invariant ADR-0019 actually cared about: a
/// placeholder cover and the two bars under it are visibly the same material.
/// They were the same breath; they are now the same sweep, off the same shader
/// with the same pair of greys and the same per-index phase.
/// Reduce Motion, as the placeholders act on it.
///
/// A free function rather than an injected environment value because
/// `\.accessibilityReduceMotion` is read-only: SwiftUI publishes it and will not
/// take an override, so `-reduceMotion` cannot be applied once at the root the
/// way `appearance` is. Each reader combines the two, and this is the one place
/// that combination is written.
///
/// Compiles away entirely in a shipping build.
enum Motion {
    static func isReduced(_ environment: Bool) -> Bool {
        #if DEBUG
        environment || DebugLaunch.forcesReduceMotion
        #else
        environment
        #endif
    }
}

enum Skeleton {
    /// The resting body of every placeholder - a bar, and now a cover too.
    ///
    /// **Not `SortyTheme.surface`, and that is a measurement rather than a
    /// preference.** `surface` is pure white in light, and these shapes sit on
    /// `background`, which is a *tinted* near-white - so a surface-coloured
    /// placeholder in light is lighter than the field it is drawn on and
    /// effectively invisible. Measured on `44-playlists-pending`: a cover
    /// placeholder came back at RGB 252 against a field of 244, which is a white
    /// card on a grey field rather than a shape waiting to be filled.
    /// `raisedSurface` is the token that is a step *away* from the field in both
    /// Appearances, which is the property a placeholder needs.
    ///
    /// Covers used to be exempt, on the grounds that a cover tile carries a card
    /// shadow describing its edge. Two things ended the exemption: the shadow is
    /// on the *tile*, so the row and track-list placeholders never had one, and a
    /// travelling band needs a body to travel across. A white cover had none.
    static var base: Color { SortyTheme.raisedSurface }

    /// The bright pass of the sweep.
    ///
    /// **Lighter than `base` in both Appearances, which the old pair was not.**
    /// The breath moved between `raisedSurface` and a *darker* grey in light
    /// (0.87) and a *lighter* one in dark (0.26), because a breath has no
    /// direction and either reads as movement. A shimmer does have one: it is
    /// light passing over a surface, and light that darkens the surface in one
    /// Appearance and brightens it in the other is two different effects sharing
    /// a name.
    ///
    /// Authored per Appearance rather than derived, for the reason `SortyTheme`
    /// gives about `accentWash`: one alpha over two very different fields gives a
    /// good result on at most one of them. Light sweeps to pure white, which on a
    /// 0.925 body is the brightest a band can be; dark sweeps to 0.34, which is
    /// the same step up from 0.21 that light gets, measured in L\* rather than in
    /// raw white.
    static func highlight(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.34) : Color(white: 1)
    }

    /// One full sweep, and `CoverShimmer.cycle` to the value.
    ///
    /// **Far outside the app's 0.14-0.25s transition budget, on purpose.** That
    /// budget is for transitions, and a transition is a thing that ends. This is
    /// ambient texture on a surface that may be there for six seconds, and the
    /// same rule that makes a 0.18s cross-fade right makes a 0.18s pulse read as
    /// an error light.
    ///
    /// It is also the span the per-index phases are spread across, so twelve
    /// placeholders divide one cycle between them rather than clustering inside
    /// part of it.
    static var period: Double { CoverShimmer.cycle }

    /// The clock every shimmer runs on, wrapped into a single cycle.
    ///
    /// **Reduced here, in `Double`, because the shader cannot do it in `float`.**
    /// The obvious uniform is `timeIntervalSinceReferenceDate`, and it is what
    /// this shipped with for a day: about 8.1e8 seconds, which a 32-bit float
    /// resolves to roughly 64-second steps. Every sweep in the app stood
    /// perfectly still, at whatever position that quantised value happened to
    /// name, and the bug is invisible in code review because the Swift side is
    /// a `Double` and looks fine - `44-playlists-pending` caught it as a flat
    /// tile measuring RGB 252 across its whole width.
    ///
    /// Wrapping to `[0, period)` rather than subtracting a launch epoch also
    /// means precision never degrades no matter how long the app stays open, and
    /// that a recycled cell re-enters the sweep exactly where its `phase` says it
    /// should rather than wherever its own lifetime had reached.
    static func clock(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
    }

    /// How often the sweep is redrawn. **Thirty a second, not display rate.**
    ///
    /// `.animation` ticks at the display's own rate, so twelve placeholder rows
    /// of three shapes were asking for up to a hundred and twenty view-body
    /// evaluations a second each, for a band that crosses a tile in 2.2 seconds.
    /// Thirty is enough because of what is moving: the band is soft by
    /// construction - `halfWidth` 0.38 with a smoothstep on both flanks, so there
    /// is no edge to step - and it travels about 180 points a second, which is
    /// six points a frame here.
    ///
    /// **The frame-drop argument for this did not survive the device, and the
    /// energy one did.** On the simulator the shimmer measured as 34 of 300
    /// frames over 20ms; on an iPhone 16 Pro the same build measured 0 of 45
    /// during a push, and so did the version without any of this. Redrawing a
    /// soft two-second gradient at display rate is still waste, and waste on a
    /// screen that exists precisely because the listener is waiting on a network
    /// is worth not spending - but nobody was ever going to see it as jank. See
    /// ADR-0024.
    ///
    /// Anchored to the reference date rather than to `.now` so the schedule is
    /// the same one on every body evaluation instead of restarting each time.
    static let tick: Double = 1.0 / 30.0

    /// The schedule's anchor. A fixed date rather than `.now`, so every body
    /// evaluation names the same schedule instead of restarting one.
    static let epoch = Date(timeIntervalSinceReferenceDate: 0)

    /// How long a placeholder holds still before it begins to shimmer.
    ///
    /// **This is a composition rule, not a performance one, and it is worth
    /// being exact about which.** It was written as a performance fix: on the
    /// simulator, holding the sweep during a push took the transition from 32 of
    /// 150 frames over 20ms down to 13. On an iPhone 16 Pro neither version drops
    /// a frame - 0 of 45 either way - so the jank being fixed only ever existed
    /// in the simulator. ADR-0024 records the whole of that.
    ///
    /// What survives is what the change does to the picture. A zoom scales a
    /// whole screen while twelve bands sweep across the rows inside it: two
    /// motions on one surface, neither related to the other, and the one the
    /// listener asked for is the one competing for attention. Holding the
    /// placeholders until the screen has stopped moving leaves the transition
    /// alone, and the sweep begins on a screen at rest.
    ///
    /// A load that beats the delay never shimmers at all, which is the right
    /// outcome by ADR-0015's own test: a placeholder replaced in a third of a
    /// second should not have announced itself.
    static let wakeDelay: Double = 0.45

    /// How long the sweep takes to reach full strength once it wakes.
    ///
    /// Without it the band would appear at whatever position the shared clock
    /// had already reached - a bright diagonal arriving from nowhere. Ramping
    /// `motion` instead means the surface is flat at the instant the clock is
    /// picked up and the band grows into it, so there is no seam to see.
    static let wakeFade: Double = 0.3
}

/// Runs a placeholder's clock, and decides when it is allowed to start.
///
/// Extracted because `SkeletonShape` and `CoverShimmer` have to make exactly the
/// same three decisions - hold still under Reduce Motion, hold still while the
/// screen arrives, fade in rather than cut in - and a placeholder cover that woke
/// on a different schedule from the bars beneath it would break the one-material
/// invariant in the most visible way available.
/// `motion` is nil while the placeholder is held, and callers draw a plain fill
/// then rather than running the shader at zero amplitude. **That distinction is
/// worth the extra branch**: a `colorEffect` still has to be created, bound and
/// rendered even when its output is nearly constant, and mounting thirty-six of
/// them is a measurable part of what the transition was spending. The two states
/// differ by the shader's 8% resting lift - about one and a half luminance steps
/// on a 0.925 body - which is below anything an eye resolves, and the fade-in
/// covers the moment it appears.
struct ShimmerDriver<Content: View>: View {
    let reduceMotion: Bool
    @ViewBuilder var content: (_ time: Double, _ motion: Float?) -> Content

    @State private var wokeAt: Date?

    var body: some View {
        Group {
            // No `TimelineView` at all until it is earned. A paused one still
            // costs the scheduling, and the point here is to spend nothing while
            // the screen is moving.
            if let wokeAt, !reduceMotion {
                TimelineView(.periodic(from: Skeleton.epoch, by: Skeleton.tick)) { timeline in
                    let since = timeline.date.timeIntervalSince(wokeAt)
                    let motion = min(1, max(0, since / Skeleton.wakeFade))
                    content(Skeleton.clock(timeline.date), Float(motion))
                }
            } else {
                // Reduce Motion lands here for good, and gets a plain fill for
                // its trouble - which is what its own branch of the shader drew
                // anyway, at a fraction of the cost.
                content(0, nil)
            }
        }
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(Skeleton.wakeDelay))
            wokeAt = Date()
        }
    }
}

/// A placeholder in a given shape.
///
/// **Reduce Motion holds it still**, which is the branch `CoverShimmer` takes and
/// for the same reason: the breath carries no information the stillness doesn't,
/// so a listener who asked for less movement loses nothing.
///
/// Hidden from VoiceOver unconditionally. What a loading region *says* is
/// decided once, on the container - see `SkeletonRegion`.
///
/// **A `TimelineView` per bar, which ADR-0019 refused and ADR-0020 accepts.**
/// The refusal was arithmetic: a grid of twelve placeholder tiles carrying three
/// bars each is thirty-six timelines invalidating at display rate inside a
/// `LazyVGrid`, against zero for a two-value interpolation the render server
/// drives on its own. That arithmetic is unchanged and it is now simply the
/// price. A band has to *travel*, and travel is a position that differs every
/// frame - there is no two-value interpolation that produces one, so the choice
/// is a per-bar clock or no shimmer on the bars at all, and the second breaks
/// the one-material invariant that is the whole point of this type.
///
/// The cost is bounded rather than open-ended: `SkeletonPlan` caps placeholders
/// at twelve, so the worst case really is thirty-six and not four hundred.
///
/// The fill is `Skeleton.base` because the shader reads its own colours from
/// uniforms; what the fill provides is the *alpha* the effect multiplies by, and
/// that is what keeps a capsule a capsule. See the note at the end of
/// `coverShimmer`.
struct SkeletonShape<S: Shape>: View {
    let shape: S
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var reduceMotion: Bool { Motion.isReduced(systemReduceMotion) }
    private var phase: Double { SkeletonPlan.phase(at: index, period: Skeleton.period) }

    var body: some View {
        // **The two colours are resolved here, not inside the closure.**
        //
        // `Skeleton.base` and `Skeleton.highlight` each build a *new* dynamic
        // `UIColor` on every access - that is what `Color(uiColor: UIColor { … })`
        // does - and the closure below reached for them three times a frame. At
        // twelve placeholder rows carrying three shapes each, that was about six
        // and a half thousand colour allocations a second, and it was measurable
        // as dropped frames: with the shimmer running, 34 of 300 frames exceeded
        // 20ms and p95 sat at 35ms, against 2 of 300 and a clean 16.67ms with it
        // paused. Hoisted, they are built once per body evaluation and the
        // closure merely captures them.
        let base = Skeleton.base
        let highlight = Skeleton.highlight(colorScheme)

        return ShimmerDriver(reduceMotion: reduceMotion) { time, motion in
            if let motion {
                shimmer(shape, time: time, motion: motion, base: base, highlight: highlight)
            } else {
                shape.fill(base)
            }
        }
        .accessibilityHidden(true)
    }

    /// One frame of the sweep. Shared by the moving and the held-still branches
    /// so the two cannot drift apart.
    private func shimmer(
        _ shape: S,
        time: Double,
        motion: Float,
        base: Color,
        highlight: Color
    ) -> some View {
        shape
            .fill(base)
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.coverShimmer(
                        .float2(proxy.size),
                        .float(time),
                        .float(phase),
                        .float(motion),
                        .color(base),
                        .color(highlight)
                    )
                )
            }
    }
}

/// One line of text that hasn't arrived.
///
/// **The height comes from the type, not from a number.** A hard 12pt bar is
/// right at one Dynamic Type size and wrong at the other eleven, and every tile
/// this stands in for *reserves* its lines - `PlaylistTile` uses
/// `lineLimit(2, reservesSpace: true)` for exactly that reason - so a guessed
/// height is a guaranteed reflow at the handoff, which is the one thing this
/// whole exercise exists to prevent. A hidden `Text` in the same font measures
/// precisely what the real row will measure, at every size, for free.
///
/// The width is a fraction rather than a length, because a name column is
/// whatever the layout gives it: a fixed 140pt bar would overhang a three-up
/// tile and underfill a list row.
struct SkeletonLine: View {
    let font: Font
    var widthFraction: Double = 1
    var index: Int = 0

    var body: some View {
        Text(verbatim: " ")
            .font(font)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    SkeletonShape(shape: Capsule(), index: index)
                        .frame(width: max(proxy.size.width * widthFraction, 8))
                }
            }
    }
}

/// A run of placeholders, and the one thing VoiceOver hears about them.
///
/// The shapes are all `accessibilityHidden`, so without this a screen of them is
/// silent - a listener using VoiceOver would meet a heading and then nothing,
/// which is indistinguishable from an empty library. One label on the container
/// says the one true thing, and it is a *status* rather than content: it is not
/// a button, it has no value, and it will be replaced by the rows themselves.
struct SkeletonRegion<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
