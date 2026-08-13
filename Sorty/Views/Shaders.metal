#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Cover placeholder
//
// A shimmer that stands in for a cover while its file is being fetched, in place
// of a spinner.
//
// **It draws on an empty tile, never on artwork, and that boundary is the whole
// point** (ADR-0015). Spotify's guidelines say artwork "must be kept in its
// original form. Don't animate or distort it in any way. This includes applying
// overlays and blurring." A shader over a *cover* would be the named
// prohibition. This one only ever runs where there is no cover yet - the empty
// surface Sorty draws itself - and `CoverImage` stops it the instant the image
// arrives. Anyone extending this: the moment it touches a loaded cover it is a
// violation, not a design choice.
//
// **A sweep, where this used to be a ripple.** ADR-0020 reverses the "not a
// shimmer" clause of ADR-0019; the reasoning it replaces is recorded there. What
// carries over unchanged is everything the ripple got right: `phase` is
// per-tile, so a grid of twenty loading covers does not pulse as one organism -
// which reads as an error state rather than as waiting - and `motion` is the
// Reduce Motion branch, holding the surface at its resting value rather than
// freezing the band mid-tile, which would read as a rendering fault.
[[ stitchable ]] half4 coverShimmer(float2 position, half4 color, float2 size,
                                    float time, float phase, float motion,
                                    half4 base, half4 highlight) {
    float2 uv = position / max(size, float2(1.0));

    // The sweep axis, diagonal. Normalised coordinates rather than points, so
    // the band is the same fraction of a 44pt thumbnail as of a 180pt tile -
    // and so a 140x12 bar gets the same treatment, where the diagonal flattens
    // into a band travelling left to right. One material for every placeholder
    // shape, which is the property ADR-0019 asked for and got from the breath.
    float band = (uv.x + uv.y) * 0.5;

    // Half the band's width, in `band` units.
    //
    // Wide on purpose, and this is the number that decides whether the effect
    // reads as calm or as a progress bar. A narrow band is a highlight passing
    // over a surface and the eye tracks it, times it, and waits for the next
    // one. A wide one is the surface itself brightening and dimming, and at
    // 0.38 the band is most of the tile at any moment - there is no edge to
    // follow, so nothing to time.
    const float halfWidth = 0.38;

    // One pass every `cycle` seconds, the band starting and ending fully clear
    // of the tile so passes are separated by a real rest rather than by a wrap.
    //
    // 2.2s against the ripple's nine-second breath. A sweep has to be quicker
    // than a breath or it stops reading as one gesture, and slower than the
    // ~1.2s web idiom or it reads as the frantic loading bar ADR-0015 removed.
    const float cycle = 2.2;
    float travel = fract((time + phase) / cycle);
    float centre = travel * (1.0 + 2.0 * halfWidth) - halfWidth;

    float d = clamp(abs(band - centre) / halfWidth, 0.0, 1.0);
    float s = 1.0 - d;
    // Smoothstep shaping, so the band has no edge on either side. A linear
    // falloff leaves a visible crease where the ramp begins, which is the same
    // mistake the progressive blur's mask makes when its curve is undersampled.
    s = s * s * (3.0 - 2.0 * s);

    // What the surface reads as between passes. Low rather than zero because the
    // band leaves the shape entirely at each end of its travel, and a placeholder
    // that snaps to a perfectly flat `base` in that gap looks like the shader
    // stopped. `base` is already a step away from the field, so this is a lift
    // off a visible body rather than the only thing making the body visible.
    const float rest = 0.08;
    float m = clamp(rest + s * 0.9 * motion, 0.0, 1.0);

    float3 col = mix(float3(base.rgb), float3(highlight.rgb), m);

    // TPDF dither. Two nearly-equal greys separated by a smooth gradient is the
    // textbook case for 8-bit banding, and a placeholder is a large flat area.
    float n1 = fract(52.9829189 * fract(dot(position,        float2(0.06711056, 0.00583715))));
    float n2 = fract(52.9829189 * fract(dot(position + 23.7, float2(0.06711056, 0.00583715))));
    col += (n1 + n2 - 1.0) * 1.1 / 255.0;

    // Premultiplied by the source alpha, which is what lets one shader serve a
    // square cover and a capsule text bar. A cover is a filled `Rectangle` whose
    // alpha is 1 everywhere, so this is a no-op there; a `SkeletonShape` is a
    // capsule, and without this the effect would paint its bounding box and
    // every bar would come back a rectangle with soft edges nowhere.
    // Multiplying rather than branching also keeps the shape's antialiased edge,
    // where alpha is fractional.
    return half4(half3(clamp(col, 0.0, 1.0)), 1.0h) * color.a;
}

// MARK: - Splash mark
//
// A diagonal sweep across Sorty's mark, brightening only the pixels the mark
// actually covers so it reads as light catching it rather than a box passing
// over it. Modelled on Beam's splash, in Sorty's own colour.
[[ stitchable ]] half4 markShimmer(float2 position, SwiftUI::Layer layer,
                                   float2 size, float time) {
    half4 src = layer.sample(position);
    float2 uv = position / max(size, float2(1.0));

    float band = (uv.x + uv.y) * 0.5;   // 0..1 along the diagonal
    float sweep = fract(time * 0.45);   // one pass roughly every 2.2s
    float centre = sweep * 1.6 - 0.3;   // travels fully across, with margin
    float s = smoothstep(0.22, 0.0, abs(band - centre));

    // Multiplied by src.a so the sweep lands on the mark and not on the tile's
    // transparent margin.
    //
    // Weaker than Beam's 0.85, and the difference is the shape underneath, not
    // taste. Beam sweeps a logo whose background is transparent, so the light
    // catches its strokes and nothing else. Sorty's mark is a *filled* tile, so
    // the same band washes the entire square - and at 0.55 it drove the leading
    // corner to white, which in a still reads as a rendering fault rather than
    // as light. Wider band, lower peak: the sweep travels instead of flaring.
    half3 highlight = half3(1.0h, 0.98h, 1.0h);
    src.rgb += highlight * half(s) * src.a * 0.34h;
    return src;
}
