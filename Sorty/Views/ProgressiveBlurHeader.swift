import SwiftUI

// MARK: - Progressive blur header

/// A progressive (variable-radius) blur: strongest at the top edge, fading to
/// clear below.
///
/// Ported from Beam's `Brand.swift`, which took it from the
/// dominikmartn/ProgressiveBlurHeader pattern. It drives the private
/// `variableBlur` CAFilter, the same one UIKit uses for its own navigation-bar
/// and keyboard blurs, and degrades to no blur at all if that private API ever
/// changes - `makeVariableBlurFilter` returns nil and the view is simply a
/// plain effect view with its tint hidden.
struct VariableBlurView: UIViewRepresentable {
    /// Deliberately low, and lowered again on device.
    ///
    /// The backdrop samples at the screen's own scale (see `didMoveToWindow`),
    /// so this is applied against a 3x grid on a 3x device, and a Gaussian's
    /// visible smear runs about three times its radius. A nominal 6 read as
    /// roughly 20pt of smear across the covers and was the "too strong" everyone
    /// kept seeing; 3 was the first correction and still read heavy on hardware,
    /// where artwork passing under the bar smeared further than it does in a
    /// simulator screenshot. 2 is about 7pt of smear, which is enough to
    /// separate the chrome from what scrolls under it without dissolving it.
    var maxBlurRadius: CGFloat = 2
    /// Points at the **bottom** over which the blur ramps out. Everything above
    /// it is solid.
    ///
    /// Expressed as the fade rather than as the solid height on purpose: this
    /// view is routinely taller than the frame SwiftUI gives it, because it
    /// reaches up under the status bar, and the amount it gains is not knowable
    /// from in here - a view that ignores the safe area reports a top inset of
    /// zero, so measuring the extra and adding it to the solid part silently
    /// computed a solid region ~60pt short and let content show through the bar
    /// it was meant to back. The fade is the same number of points however tall
    /// the view ends up, so deriving the ramp from it is stable.
    var fadeHeight: CGFloat = 0

    func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(maxBlurRadius: maxBlurRadius, fadeHeight: fadeHeight)
    }

    func updateUIView(_ uiView: VariableBlurUIView, context: Context) {
        uiView.fadeHeight = fadeHeight
    }
}

final class VariableBlurUIView: UIVisualEffectView {
    private let maxBlurRadius: CGFloat
    private var blurFilter: NSObject?
    /// The fraction of the ramp the last mask was built for, so layout does not
    /// rebuild a gradient that has not changed.
    private var builtHold: Double?

    var fadeHeight: CGFloat {
        didSet { if fadeHeight != oldValue { setNeedsLayout() } }
    }

    init(maxBlurRadius: CGFloat, fadeHeight: CGFloat) {
        self.maxBlurRadius = maxBlurRadius
        self.fadeHeight = fadeHeight
        super.init(effect: UIBlurEffect(style: .regular))
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let scale = window?.screen.scale, let backdrop = subviews.first {
            backdrop.layer.setValue(scale, forKey: "scale")
        }
    }

    // The system rebuilds the effect view's backdrop layer - wiping the filter
    // and re-showing its tint - whenever the appearance changes. Sorty makes
    // that a routine event rather than a rare one, since Appearance is a
    // setting the user can flip, so re-applying here is what keeps the blur
    // from silently reverting to a flat grey bar.
    //
    // It is also the only place the hold can be worked out. The mask is a
    // fraction of the ramp, `solidHeight` is in points, and the two are only
    // relatable once the view has a height - which, where this reaches under the
    // status bar, is taller than the frame SwiftUI asked for.
    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildMaskIfNeeded()
        applyBlur()
    }

    private func rebuildMaskIfNeeded() {
        let total = bounds.height
        guard total > 0 else { return }
        // Solid everything except the last `fadeHeight` points, whatever the
        // view's height turned out to be once the safe area was added to it.
        // Never a full 1: a mask with no ramp at all stopped the filter
        // rendering entirely - the bar it was backing went clear and list rows
        // read straight through it - and the two points this costs are not
        // visible on any screen.
        let hold = max(0, min(0.98, Double((total - fadeHeight) / total)))

        guard builtHold == nil || abs(hold - (builtHold ?? -1)) > 0.01 else { return }
        builtHold = hold
        blurFilter = Self.makeVariableBlurFilter(maxBlurRadius: maxBlurRadius, hold: hold)
        // A rebuilt filter is a different object, so the identity check in
        // `applyBlur` will install it.
    }

    /// **The tint is hidden first, and unconditionally.** It used to be hidden
    /// after a `guard` that also required the filter, which made the documented
    /// fallback do the exact opposite of what it promises: on any device where
    /// the private `CAFilter` lookup fails, `blurFilter` is nil, this returned
    /// early, and what was left was not "a plain effect view with its tint
    /// hidden" but a full-strength `.regular` material rectangle 278pt tall with
    /// a hard bottom edge - the worst possible version of the seam this whole
    /// file exists to avoid, on precisely the devices that could not report it.
    /// The nil result is sticky too, since `rebuildMaskIfNeeded` only retries
    /// when `hold` moves.
    private func applyBlur() {
        for tint in subviews.dropFirst() where tint.alpha != 0 { tint.alpha = 0 }
        guard let blurFilter, let backdrop = subviews.first else { return }
        if (backdrop.layer.filters?.first as? NSObject) !== blurFilter {
            backdrop.layer.filters = [blurFilter]
        }
    }

    private static func makeVariableBlurFilter(maxBlurRadius: CGFloat, hold: Double) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let made = filterClass.perform(NSSelectorFromString("filterWithType:"), with: "variableBlur"),
              let blurFilter = made.takeUnretainedValue() as? NSObject,
              let mask = gradientMask(hold: hold)
        else { return nil }
        blurFilter.setValue(maxBlurRadius, forKey: "inputRadius")
        blurFilter.setValue(mask, forKey: "inputMaskImage")
        blurFilter.setValue(true, forKey: "inputNormalizeEdges")
        return blurFilter
    }

    /// Vertical alpha gradient: opaque (full blur) at the top, clear (no blur)
    /// at the bottom.
    ///
    /// **Not a straight line, and that is the whole point.** A two-stop linear
    /// ramp fades the blur at a constant rate, which the eye reads as a band
    /// with a visible top and bottom rather than as a fade - the radius is still
    /// changing measurably at the last pixel, so the effect appears to stop
    /// rather than to run out. The ramp here holds at full blur for `hold` of
    /// its length, then follows a smoothstep, whose gradient is zero at both
    /// ends. That is what makes both edges disappear.
    ///
    /// `hold` is what makes the header solid. Before it existed the ramp began
    /// fading from the very first pixel, so a header sat on a backdrop that was
    /// already half clear by its own bottom edge - the chips on the playlist
    /// screen had rows showing through them while the notice a few points lower
    /// was smeared. Full blur for the header's own height, fade only below it.
    ///
    /// Sampled into many stops rather than expressed as a curve because
    /// `CGGradient` interpolates linearly between whatever stops it is given;
    /// the curve has to be baked in.
    ///
    /// **The stops are spent inside the ramp, and that is the correction.** They
    /// used to be spread evenly across the whole gradient - 64 of them over
    /// `t` from 0 to 1 - which sounds like plenty and is not, because the curve
    /// only exists above `hold`. A 58pt header with a 20pt fade and the default
    /// overscan gives `hold` = 0.928, so the ramp got 64 x 0.072 ≈ **four and a
    /// half stops**, and `CGGradient` joined them with straight lines. The
    /// smoothstep whose whole purpose is a gradient of zero at both ends was
    /// being rendered as a four-segment polyline with a corner at each end - so
    /// the blur left full strength at a measurable rate and arrived at nothing at
    /// a measurable rate, which is exactly the visible start and visible finish
    /// the curve was chosen to remove. The solid region needs two stops, not
    /// sixty-two; everything else belongs to the ramp.
    ///
    /// **Smootherstep rather than smoothstep**, for the residue the sampling fix
    /// leaves behind. Smoothstep's first derivative is zero at both ends but its
    /// second is not - it is ±6 there - and a discontinuity in the *rate* of
    /// change is what the eye reports as a Mach band: a faint bright or dark line
    /// at the join, visible precisely where the effect is meant to disappear.
    /// The quintic 6u⁵-15u⁴+10u³ zeroes the second derivative as well, so there
    /// is no join to find.
    ///
    /// 2048 rows deep because the ramp is a small fraction of the image and gets
    /// that fraction of the rows: at the original 512 a 7% ramp was 37 rows
    /// stretched over about 60 device pixels, and the steps themselves became the
    /// banding they were meant to remove.
    private static func gradientMask(hold: Double) -> CGImage? {
        let height = 2048
        let rampStops = 96

        var colors: [CGColor] = []
        var locations: [CGFloat] = []

        let opaque = UIColor(white: 0, alpha: 1).cgColor
        colors.append(opaque)
        locations.append(0)
        if hold > 0 {
            colors.append(opaque)
            locations.append(CGFloat(hold))
        }

        for step in 1...rampStops {
            let u = Double(step) / Double(rampStops)
            let eased = u * u * u * (u * (u * 6 - 15) + 10)
            colors.append(UIColor(white: 0, alpha: 1 - eased).cgColor)
            locations.append(CGFloat(hold + u * (1 - hold)))
        }

        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: height)).image { ctx in
            let cg = ctx.cgContext
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: colors as CFArray,
                locations: locations
            ) else { return }
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        }.cgImage
    }
}

/// The blur alone, for a screen whose header is already positioned.
///
/// Reaches `fade` points past the header's own height so the transition
/// finishes before the first row rather than smearing it.
///
/// **It must be layered above the content and below the header, and the
/// difference between `.background` and `.overlay` decides which.** The blur is
/// for what passes *under* a header; a header drawn inside it is destroyed by
/// it. So:
///
/// - Behind a header this view owns - a `safeAreaInset`, a pinned section row -
///   attach it with `.background(alignment: .top)` on the header itself.
/// - Under a **system** bar, which is drawn above everything a view can attach,
///   `.overlay(alignment: .top)` on the scroll view is correct and is the only
///   case where it is.
///
/// Getting this backwards is not subtle and is not a build error: it renders the
/// title as a smear, which is exactly what the library screen shipped.
struct TopBlur: View {
    /// The height of the thing this backs, which stays at **full** blur. Pass
    /// the header's own height, not zero: everything above `height` is solid
    /// and the fade happens entirely below it.
    var height: CGFloat
    /// Softer than it was. See `VariableBlurView.maxBlurRadius` for the
    /// measurement behind the number; this default is the only place any screen
    /// gets it from, so changing it here changes every blur in the app at once.
    var maxBlur: CGFloat = 2
    /// How far past `height` the blur takes to reach nothing.
    ///
    /// **The same on every screen, deliberately.** This is the distance over
    /// which anything scrolling underneath disperses, so a different value per
    /// screen means the library, the playlist and the sheet each let content go
    /// at a different rate and stop feeling like one app. Call sites do not pass
    /// it; whatever needs to clear the band adjusts its own padding instead.
    ///
    /// **40 rather than 20, and the curve is why.** A smootherstep spends its
    /// length unevenly on purpose - the tails are nearly flat, which is what
    /// makes both ends disappear, and the cost is that the actual change is
    /// concentrated in the middle third. Measured off `26-tracks-scrolled` by
    /// the high-frequency energy in the artwork passing underneath: at a 20pt
    /// fade the cover went from fully smeared to fully sharp between y=360 and
    /// y=390 device pixels, which is ten points. Soft-edged, but a ten-point
    /// transition is still a band with a place where it happens. Doubling the
    /// fade gives the middle third about twenty points to work in, and that is
    /// the difference between an edge you cannot find and one you can.
    var fade: CGFloat = Self.defaultFade

    /// The one dispersion every screen shares.
    ///
    /// A constant rather than a repeated literal, because it was a repeated
    /// literal and that is how the first attempt at this change did nothing:
    /// `ScreenTopBar` declared its own `fade` defaulting to 20, under a comment
    /// promising it was "handed straight to `TopBlur`, whose default is the one
    /// dispersion every screen shares". Raising the default here left every
    /// screen that goes through the shared bar - which is most of them - on the
    /// old value, and the measurement came back unchanged. One definition, and
    /// the comment is true by construction.
    static let defaultFade: CGFloat = 40
    /// How far the solid region reaches **above** this view's own top edge.
    ///
    /// `ignoresSafeArea(edges: .top)` used to do this job and could not: it is a
    /// no-op from inside a `safeAreaInset`, because the inset has already
    /// consumed the top inset and there is none left to ignore. The blur then
    /// stopped at its owner's top edge and list rows read straight through the
    /// status bar above it.
    ///
    /// Growing the view and pulling it back by the same amount does not care
    /// where the safe area went. It is free: the mask is "solid except the last
    /// `fade` points", so extending the top only lengthens the solid part and
    /// the bottom edge lands at `height + fade` either way.
    ///
    /// Pass 0 inside a sheet, whose own top edge is already the top of the
    /// world and where reaching past it draws over the presenting screen.
    var overscan: CGFloat = 200

    var body: some View {
        VariableBlurView(maxBlurRadius: maxBlur, fadeHeight: fade)
            .frame(maxWidth: .infinity)
            .frame(height: overscan + height + fade)
            .padding(.top, -overscan)
            .allowsHitTesting(false)
    }
}

// A `ProgressiveBlurHeader` container used to live here, stacking content, blur
// and header in one ZStack. It was never used by any screen, and its ordering
// was the mistake the note on `TopBlur` warns about: every screen that wants a
// pinned header already has one, via `safeAreaInset` or a pinned section, and
// what those screens need is the blur placed correctly relative to it. Keeping a
// second, unused way to get that wrong was worse than having no container at
// all.
