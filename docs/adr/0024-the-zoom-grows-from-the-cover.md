# 24. The zoom grows from the cover, and the simulator lied about why it was slow

Date: 2026-08-13

## Status

Accepted. Refines [ADR-0021](0021-a-playlist-opens-by-growing.md), which
established the zoom and named the whole tile as its source.

## Context

Two questions, one of which had an answer nobody had checked.

**What should the screen grow out of?** 0021 put `.matchedTransitionSource` on
the whole button - cover, name and owner - reasoning that the zoom should start
from the target the finger hit. What that produces is a portrait rectangle of
mostly text unfolding into a full screen. The library and the track list share
exactly one thing, and it is the artwork: the destination opens on that same
cover, large and centred.

**Why did it feel slow?** The placeholders shimmer, and a track list mounts
twelve rows of three shimmering shapes. Every one of them started its clock while
the screen was still scaling.

## Decision

**The source is the cover, not the cell.** `playlistZoomSource(id:in:)` is
applied to `CoverImage` in both layouts, and carries `PlaylistArtwork.radius`
into the transition as a clip shape so the artwork does not change corner on its
way there. That radius is now a constant precisely because a fifth place reads
it; four literals and a transition that quietly disagreed with them is the defect
this prevents.

**Placeholders hold still until the screen has arrived** - `Skeleton.wakeDelay`,
0.45s, then a 0.3s ramp on the shader's `motion` uniform so the band grows in
rather than appearing mid-sweep. While held they draw a plain fill and no shader
at all.

**The sweep redraws thirty times a second**, not at display rate.

**The two colours are resolved once per body evaluation.** `Skeleton.base` and
`Skeleton.highlight` build a *new* dynamic `UIColor` on every access, and the
per-frame closure reached for them three times - about six and a half thousand
allocations a second across twelve rows. This one is unambiguous and would be
worth doing on any hardware.

## Consequences

**The performance case for two of those changes did not survive the device, and
this is the part worth reading.**

Measured on the simulator, on a warm push driven by the new `-pushAfter` (the
library already drawn, a `CADisplayLink` probe started at the moment the path
changes):

| | p95 | over 20ms |
|---|---|---|
| shimmer running during the push | 50-73ms | 7-12 of 45 |
| shimmer held | 33ms | ~13 of 150 |
| Reduce Motion (no shimmer, no zoom) | 16.67ms | 0-1 of 45 |

A fifth of the transition's frames, apparently. Then the same build on an
iPhone 16 Pro:

| | p95 | max | over 20ms |
|---|---|---|---|
| with every fix | 16.67ms | 110ms | 1 of 45 |
| **with none of them** | **16.67ms** | **16.76ms** | **0 of 45** |

The jank was the simulator's, entirely. The pre-fix build is if anything the
cleaner of the two on real hardware. **A simulator frame timing is not evidence
about a transition** - it renders through a completely different path, and it was
wrong here by about twenty percentage points.

The changes are kept, on grounds that are now stated honestly rather than
borrowed from a number that evaporated:

- **Hoisting the colours** is correct on any hardware. Nothing to re-argue.
- **Thirty a second** is an energy argument, not a smoothness one. Redrawing a
  soft two-second gradient at 120Hz is waste, and it is waste on a screen that
  exists because the listener is already waiting on a network.
- **The wake delay is a composition rule.** A zoom scales a whole screen while
  twelve bands sweep across the rows inside it: two unrelated motions on one
  surface, and the one the listener asked for is the one competing for
  attention. It also means a load that beats 0.45s never shimmers at all, which
  is the right outcome by ADR-0015's own test - a placeholder replaced in a third
  of a second should not have announced itself.

**`-pushAfter` is a permanent harness argument, and it earned that.** Without it
every measurement of "the transition" was really a measurement of process start,
the demo catalogue and the splash, with the push somewhere inside. It is the same
family as `-advanceAfter`: the only way to produce, without a finger, the warm
push a listener actually performs.

**The frame probe that produced these numbers was temporary and is gone.** What
it measured is written down here because the next person to wonder whether the
shimmer is expensive should not have to rebuild it - and should not trust the
simulator when they do.
