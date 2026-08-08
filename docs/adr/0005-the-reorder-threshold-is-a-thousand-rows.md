# 5. The reorder threshold is a thousand rows

Date: 2026-08-06

## Status

Accepted.

## Context

The redesign spec left this number deliberately unresolved: "the reorder
threshold has to be measured on a device… Any ticket that assumes either is the
signal to take a prototype detour first." Ticket 09 restates it: "The threshold
is a measurement, not a guess."

The premise behind the threshold was that a long playlist would make the reorder
animation stutter, and that above some size snapping would be kinder than a
laggy spring.

## Method

A `CADisplayLink` sampler (`Sortify/Support/ReorderProfiler.swift`) counts
frames across a reorder and flags any whose gap from the previous frame exceeds
1.5× what the display asked for. The expected duration is read per frame from
the link rather than assumed, because ProMotion changes it underneath you.

Driven by `-screen profile -count N` (`ReorderProfileView`), which builds a
playlist of N invented tracks with Attributes on coprime strides - so no two
Arrangements agree on an order and every reorder genuinely moves every row -
and then drives the **real** `TrackListModel` and `TrackListView`. A
purpose-built list would have measured the harness.

Run on **Serein, an iPhone 16 Pro (A18 Pro), iOS 27**, installed via
`devicectl`. Not in the simulator: simulator frame timing is the Mac's.

Two scenarios per size:

- **Single reorder** - one Arrangement applied, sampled for 900ms while the
  spring settles. Three passes over six Arrangements: 18 samples per size.
- **Rapid burst** - six Arrangements applied 80ms apart, faster than anyone can
  tap distinct chips, sampled until settled. This is ticket 09's "rapidly
  switching Arrangements does not queue or stack".

One caveat, stated because it bounds the claim: without
`CADisableMinimumFrameDuration` in the Info.plist, iOS caps `CADisplayLink` at
60Hz. So these are **main-thread stalls sampled at 60Hz**, not true 120Hz frame
pacing. A stalled main thread is what a listener sees as a stutter and what
would make scrolling unresponsive during a reorder, so it is the right quantity;
it just cannot speak to sub-16ms pacing.

## Measurements

Single reorder, 18 samples per size:

| rows   | late frames (total/18) | median worst | max worst  |
| -----: | ---------------------: | -----------: | ---------: |
|    100 |                     15 |        1.67× | 3.72× (62ms) |
|    250 |                     13 |        0.00× | 4.73× (79ms) |
|    500 |                      9 |        0.00× | 6.75× (112ms) |
|  1,000 |                      7 |        0.00× | 4.49× (75ms) |
|  2,500 |                     12 |        1.58× | 5.93× (99ms) |
|  5,000 |                      9 |        1.57× | 6.80× (113ms) |

**Flat.** A reorder of 5,000 rows costs what a reorder of 100 costs, and the
spread is noise rather than trend - 500 rows measured worse than 1,000. An
earlier sweep to 10,000 (Spotify's own playlist ceiling) agreed: 0–1 late frames
per reorder.

The reason is structural. `LazyVStack` lays out only the rows on screen, so the
spring animates about a dozen of them however long the playlist is, and the sort
itself is sub-millisecond even at five thousand.

Rapid burst - six Arrangements in 480ms:

| rows  | late frames | worst |
| ----: | ----------: | ----: |
|   100 |     10 / 78 | 2.65× |
| 1,000 |     11 / 75 | 5.28× |
| 5,000 |     15 / 63 | 6.56× |

Here size finally appears: 13% of frames late at 100 rows, 15% at 1,000, 24% at
5,000. The animations do **not** queue - six queued springs would have held the
window late for 2.4 seconds, and it settles in about 1.4 - but the cost of
changing your mind quickly does grow.

## Decision

**Snap above 1,000 rows.** Reduced Motion snaps at any size.

The number comes from the burst table, because that is the only place size
showed up: the cost of a listener changing their mind quickly is flat to about a
thousand rows and is not flat beyond it.

It is deliberately *not* derived from the single-reorder table, which supports
no threshold at all within the range a Spotify playlist can reach.

## Consequences

**The threshold guards a stress case, not the common one.** A listener applying
one Arrangement to a 3,000-track playlist would have been fine. They now get a
snap. That is accepted: the alternative is a rule that only holds while nobody
taps twice.

**Do not raise it from intuition, and do not lower it either.** If row rendering
gets more expensive - a per-row waveform, say - the single-reorder table stops
being flat and the number has to be taken again. The harness is still in the
repo for exactly that: `-screen profile -count N`, `REORDER-PROFILE` lines on
the console.

**These numbers are one device.** An A18 Pro is the fast end of what iOS 27
runs. The costs are not size-dependent, so a slower phone scales the hitch
rather than moving the threshold - which is why the answer to a slow device is
to re-measure, not to lower a row count that was never the lever.
