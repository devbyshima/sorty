# 20. The placeholder shimmers, and one shader draws all of it

Date: 2026-08-13

## Status

Accepted. Reverses the "not a shimmer" clause of
[ADR-0019](0019-a-skeleton-is-the-shape-of-what-is-coming.md) and the ripple it
inherited from [ADR-0015](0015-waiting-is-texture-not-status.md). Everything
those two decided about the *compliance* boundary stands untouched and is
restated below, because it is the one part of them that was never about taste.

## Context

0019 argued against a shimmer in three moves, and only one of them survives.

> a directional shimmer sweeping a list says *thirty-eight percent of the way
> there*, which is a status readout wearing texture's clothes

This is the argument that no longer holds, and it was always the weakest of the
three because it is a claim about how a listener reads a moving band rather than
a fact about the app. A sweep reads as progress when it is narrow, fast and
tracks the width of the thing it crosses - the loading-bar shape. It does not
when the band is wider than most of the tile, when there is a rest between
passes, and when every tile on screen is at a different phase. Twelve tiles
sweeping out of step with one another cannot be read as one measurement of
anything; that is the same property `phase` was already introduced for, doing a
second job.

> `coverRipple`'s geometry is square-specific and stretches into extreme
> ellipses on a 140×12 bar

True of a ripple, and the reason 0019 kept text bars out of Metal. It is not
true of a band along `(uv.x + uv.y) * 0.5`, which on that same bar flattens into
a sweep from one end to the other. The geometric objection was an objection to
`length(uv - 0.5)`, not to shaders.

> A `[[stitchable]]` function that fails to resolve is silently skipped and
> SwiftUI draws the unmodified view - which on a text bar is a flat grey
> rectangle, i.e. exactly what success looks like

This one stands, and is answered rather than dismissed. See Consequences.

## Decision

**Placeholders shimmer. `coverShimmer` draws every one of them - the covers and
the text bars - and the two are the same material by construction rather than by
agreement.**

0019 wanted a placeholder cover and the bars beneath it to be visibly one
material and got there by copying the ripple's breath out of Metal into a
SwiftUI animation, which left two implementations of one idea that had to be
kept in step by hand. They were already out of step: the cover drew itself on
`SortyTheme.surface` while the bars drew on `raisedSurface`, so on a light field
a placeholder cover measured RGB 252 against a background of 244 - a white card
where a waiting shape should be, and lighter than the field it sat on. There is
now one shader, one pair of colours (`Skeleton.base` and `Skeleton.highlight`)
and one clock.

**The sweep brightens in both Appearances.** The breath moved between
`raisedSurface` and a *darker* grey in light and a *lighter* one in dark, which a
breath can do because it has no direction. A shimmer is light passing over a
surface, and light that darkens the surface in one Appearance and brightens it in
the other is two effects sharing a name.

**The compliance boundary does not move.** This draws on the empty surface Sorty
draws itself, never on artwork. Spotify's guidelines require artwork be "kept in
its original form" with no animation, distortion, overlay or blur, so a shader
over a loaded cover is the named prohibition rather than a near miss.
`CoverImage` swaps the shimmer out the instant the image resolves, and that
ordering is the boundary. Changing a ripple into a sweep is a change of what the
empty tile looks like; it is not a change of what may be drawn on.

**Reduce Motion holds the surface at its resting value, not frozen mid-sweep.** A
stopped clock leaves the band wherever it happened to be, which in a still reads
as a rendering fault rather than as stillness. The shader takes a `motion`
uniform and renders the rest level when it is zero.

That claim is checkable rather than asserted: `48-reduce-motion` is the shot, and
the thing to check is that the placeholders are *flat*, not merely still - both
outcomes are motionless and only one of them is right. Measured, the interior
luminance spread is 5 (dither alone) against 17 with the sweep running.

## Consequences

**The silent-failure risk 0019 named is now spread over every placeholder, and
the two pending shots are the only guard.** `44-playlists-pending` and
`45-tracks-pending` have to be read as *motion* shots from now on: a still frame
of a sweep is a shape with a bright region somewhere along it, and a shape with
no bright region anywhere is a shader that did not resolve. That is a weaker
guard than 0019 wanted and it is the accepted cost of the reversal. It is not
weaker than what shipped, because the bars' hand-copied breath had no guard at
all.

**A `TimelineView` per bar, which 0019 refused on arithmetic that has not
changed.** Twelve placeholder tiles carrying three bars each is thirty-six
timelines invalidating at display rate inside a `LazyVGrid`, against zero for the
two-value interpolation the render server drove on its own. A band has to
*travel*, and travel is a position that differs every frame; there is no
two-value interpolation that produces one. The cost is bounded rather than
open-ended, because `SkeletonPlan` caps placeholders at twelve.

**The shader clock is reduced to one cycle in Swift, and must stay that way.**
The obvious uniform is `timeIntervalSinceReferenceDate`, which is about 8.1e8
seconds - a 32-bit float resolves that to roughly 64-second steps, so every sweep
in the app stands perfectly still at whatever position the quantisation names.
This shipped for a day and was caught by measuring `44-playlists-pending`: a flat
tile reading RGB 252 across its entire width. `Skeleton.clock` wraps the interval
into `[0, period)` before it crosses into Metal, which also means precision never
degrades however long the app stays open, and that a recycled cell re-enters the
sweep where its `phase` says rather than wherever its own lifetime had reached.

**`-reduceMotion` exists, and it is a combiner rather than an injection.**
`\.accessibilityReduceMotion` is a read-only environment key - SwiftUI publishes
it and will not take an override - so unlike `appearance` this cannot be applied
once at the root. `Motion.isReduced(_:)` is the one place the harness flag and
the system value are combined, and each reader calls it. The obvious alternative,
one `.environment` whose value is `forced ? true : UIAccessibility.isReduceMotionEnabled`,
is worse than it looks: that static reads once and pins the environment to a
snapshot, so a listener who turns Reduce Motion on while Sorty is open would keep
every animation until they relaunched.

**`CONTEXT.md`'s Placeholder entry no longer lists "shimmer" among the words to
avoid.** It still lists "loading state", "spinner" and "skeleton screen", which
are about what the app *says*; "shimmer" was the only entry describing what it
draws.
