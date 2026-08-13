# 23. The blur has no edge to find

Date: 2026-08-13

## Status

Accepted. Retunes the progressive blur introduced with the header rebuild; the
architecture (a private `variableBlur` `CAFilter` behind a
`UIVisualEffectView`, masked by a baked gradient) is unchanged.

## Context

The blur had a visible bottom edge - a place on screen where you could see the
effect stop. That is the one thing a *progressive* blur is named for not doing.

Four causes, in the order they actually matter.

**The ramp was too short for the radius it had to shed.** This is the primary
one. The eye locates the end of a blur where the radius drops below
discrimination - roughly 0.15 units, about half a point of smear. With a 20pt
fade and a max radius of 2, that crossing happened at a rate of about 0.084
radius per point, so the last detectable blur disappeared over about 3pt. Soft
edges or not, a 3pt disappearance is a place where it happens.

**The mask's stops were spent almost entirely outside the ramp.** The gradient
was 64 stops spread evenly over its whole length, but the curve only exists above
`hold` - and for a 58pt header with a 20pt fade and the default 200pt overscan,
`hold` is 0.928. That left about four and a half stops describing the entire
smoothstep, joined by straight lines. The curve chosen specifically for its zero
gradient at both ends was being rendered as a four-segment polyline with a corner
at each end.

**`applyBlur` hid the effect view's tint only when the filter existed.** The
tint-hiding loop sat below a `guard` that also required `blurFilter`. So on any
device where the private `CAFilter` lookup fails, the documented fallback - "a
plain effect view with its tint hidden" - did the exact opposite: a full-strength
`.regular` material rectangle 278pt tall with a hard bottom edge. The worst
possible version of the seam this file exists to avoid, on precisely the devices
that could not report it. The nil result is sticky, too, since the filter is only
rebuilt when `hold` moves.

**`fade` had two independent defaults.** `TopBlur.fade` and `ScreenTopBar.fade`
both declared 20, under a comment on the latter promising that `TopBlur`'s
default "is the one dispersion every screen shares". Raising one left every
screen that goes through the shared bar - which is most of them - on the old
value. The first attempt at this change measured as having done nothing.

## Decision

**`TopBlur.defaultFade` is 40, and it is a constant that both call sites read.**

**The mask spends its stops inside the ramp.** Two stops describe the solid
region; 96 describe the curve, wherever `hold` falls. The image is 2048 rows deep
rather than 512, because the ramp gets whatever fraction of the rows its own
fraction of the gradient entitles it to.

**The easing is smootherstep**, the quintic 6u⁵-15u⁴+10u³. Honestly stated: at
the threshold where the eye finds the edge, the curve barely matters - both
smoothstep and smootherstep leave a slope of about 0.85 alpha per unit of ramp
there, and the fade length is what divides it. Smootherstep is kept because its
tail is flatter *below* that threshold, which is where "when exactly did it
vanish" is decided, and because it costs nothing.

**`applyBlur` hides the tint first and unconditionally.**

## Consequences

**Every screen's top padding moved with it**, because four call sites assert a
clearance contract against the raw number: the ramp must finish in the gap above
the first row rather than across it. `PlaylistsView` goes 28 → 48,
`SettingsScaffold` 20 → 48, `TrackDetailSheet` 30 → 52. One of those was already
false before this change - the settings scaffold padded exactly 20 against a fade
of 20, so its first card sat on the last point of the ramp.

**The run-out is twice as gentle and no gentler.** About 0.042 radius per point
against 0.084. Halving it again would need an 80pt fade, which is a fifth of the
screen's width spent on a gradient, or a weaker blur - and the blur's strength was
itself measured down to 2 for reasons the code records. This is the trade, stated
so the next person does not re-derive it.

**The measurement to repeat is high-frequency energy in the artwork passing under
the bar**, off `26-tracks-scrolled`, and it has one trap: that shot now arrives
through the zoom transition (ADR-0021), so a capture taken too early measures a
part-scaled screen. It also has a second trap - the metric is content-dependent,
and a stretch of artwork with no detail reads as "fully blurred" whether it is or
not. An isolated hard edge is a better probe than interior texture.
