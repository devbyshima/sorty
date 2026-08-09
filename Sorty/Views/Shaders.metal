#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Cover placeholder
//
// A ripple that stands in for a cover while its file is being fetched, in place
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
// `phase` is per-tile, so a grid of twenty loading covers does not pulse as one
// organism - which reads as an error state rather than as waiting.
[[ stitchable ]] half4 coverRipple(float2 position, half4 color, float2 size,
                                   float time, float phase, half4 low, half4 high) {
    float2 uv = position / max(size, float2(1.0));
    float2 centred = uv - 0.5;
    float r = length(centred);

    // Rings traveling outward from the middle. The frequency is low on purpose:
    // tight rings on a 44pt thumbnail alias into noise.
    float wave = sin(r * 14.0 - (time + phase) * 2.0);

    // Falloff, so the rings dissolve toward the corners and the tile never
    // reads as a target or a radar sweep. Measured rather than chosen: at
    // exp(-r * 2.2) the rings were down to a fifth of their amplitude by the
    // corner, which on a white surface left the whole effect invisible.
    float falloff = exp(-r * 1.4);

    // A slow breath over the whole thing, so a tile that waits a long time is
    // never perfectly still and never frantic either.
    float breathe = 0.78 + 0.22 * sin((time + phase) * 0.7);

    float m = clamp((0.5 + 0.5 * wave) * falloff * breathe, 0.0, 1.0);

    float3 col = mix(float3(low.rgb), float3(high.rgb), m);

    // TPDF dither. Two nearly-equal greys separated by a smooth gradient is the
    // textbook case for 8-bit banding, and a placeholder is a large flat area.
    float n1 = fract(52.9829189 * fract(dot(position,        float2(0.06711056, 0.00583715))));
    float n2 = fract(52.9829189 * fract(dot(position + 23.7, float2(0.06711056, 0.00583715))));
    col += (n1 + n2 - 1.0) * 1.1 / 255.0;

    return half4(half3(clamp(col, 0.0, 1.0)), 1.0h);
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

// MARK: - Page transition
//
// The blur a page carries while it travels *through depth* rather than across
// the screen.
//
// `progress` is signed and runs -1 … 0 … 1: zero is the settled page, positive
// is a page still behind the viewer and growing toward them, negative one that
// has passed and is receding. The sign is the direction, which is why this takes
// a number rather than an edge - the `push(from:)` family describes both halves
// of a transition with one edge and reads backwards to almost everyone
// (ADR-0016).
//
// Radial, not directional. The earlier version smeared sideways because the page
// slid sideways; a page that scales has no single direction of travel - every
// pixel moves along its own line out from the centre, and blurring along that
// line is what makes the scale read as movement instead of as a resize.
//
// Only the blur lives here. The scale itself is an ordinary `scaleEffect`, so
// the sampler never reaches beyond the smear.
[[ stitchable ]] half4 pageZoom(float2 position, SwiftUI::Layer layer,
                                float2 size, float progress) {
    float amount = abs(progress);
    if (amount < 0.001) {
        return layer.sample(position);
    }

    float2 centre = size * 0.5;
    float2 delta = position - centre;

    // A fraction of each pixel's own distance from the centre, so the blur
    // lengthens toward the edges exactly as real radial motion does - a constant
    // length would smear the middle as hard as the corners and read as fog.
    //
    // Eased so it arrives fast and clears slowly; a linear ramp reads as the
    // page being out of focus rather than as it moving.
    float reach = pow(amount, 0.65) * 0.075 * (progress > 0.0 ? 1.0 : -1.0);

    const int taps = 7;
    half4 total = half4(0.0h);
    for (int i = 0; i < taps; ++i) {
        float t = float(i) / float(taps - 1);
        total += layer.sample(centre + delta * (1.0 - reach * t));
    }

    return total / half(taps);
}
