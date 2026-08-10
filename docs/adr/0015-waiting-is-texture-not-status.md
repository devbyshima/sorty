# 15. Waiting is texture, not status - and the shader stops at the artwork

Date: 2026-08-09

## Status

Accepted. Amended by
[ADR-0019](0019-a-skeleton-is-the-shape-of-what-is-coming.md) on 2026-08-10,
which gives the track list and the trailing edge of the library a placeholder
where this decision left them blank. The rule below stands, including the shader
boundary, which 0019 restates rather than relaxes - and so does the finding that
made this decision: `loaded`/`total` is now a layout input deciding how many
shapes to draw, and is still printed nowhere.

## Context

Sorty reported on itself in four places while it waited:

1. A spinner inside every cover that had not arrived.
2. "Loaded 12 of 40 playlists…" over a determinate bar, at the top of the library.
3. A large spinner over "Loaded 40 of 120 tracks…", filling the track screen.
4. "Connecting to Spotify" and a spinner, on the launch splash.

Every one of those was accurate. None of them was actionable. A listener does
not wait differently for knowing that 40 of 120 tracks have arrived, and cannot
do anything with the number; what the counter actually changed was the
*character* of a two-second fetch, which it turned into an operation with a
status readout.

## Decision

**Waiting is shown by texture where it needs showing, and by nothing at all
where it does not.**

- **Covers ripple.** A Metal `colorEffect` runs slow concentric waves over the
  empty tile, phase-offset per cover so a grid of twenty does not pulse as one
  organism - which reads as an error, not as loading.
- **The library and the track list show nothing.** They simply fill. Failures
  still speak, because a failure *is* actionable.
- **The splash lost its words.** Sorty's mark on a field, an accent bloom rising
  from below the bottom edge, and a shimmer sweeping the mark. Modelled on
  Beam's `SplashView`, in Sorty's own colour.

## The boundary that matters

**The ripple draws on the placeholder. It must never draw on artwork.**

This is not a stylistic preference and it is the reason this ADR exists.
Spotify's Design & Branding Guidelines:

> Artwork must be kept in its original form. Don't animate or distort it in any
> way. This includes applying overlays and blurring.

A ripple over a *loaded cover* is not a near miss of that sentence; it is the
sentence. ADR-0012 has already been here once - `StickerCover` shipped a
`plusLighter` highlight over Spotify's artwork and nobody checked it against a
warning that had been written down months earlier.

So the rule, stated for whoever extends this next: `CoverRipple` exists only in
the branch where there is no image, and `CoverImage` swaps it out the moment one
resolves. **That ordering is a compliance boundary, not a detail of the
transition.** Widening the shader to "the cover" rather than "the placeholder" -
a one-word change, and an inviting one, because it would look good - is a
violation.

The doc comments on both `CoverRipple` and the shader say this at the point of
use, because an ADR nobody opens has never once stopped this class of mistake in
this repo.

## Verification

Both effects are invisible to the existing screenshot set, and would have been
shipped unverified without new hooks.

A `[[stitchable]]` function that fails to resolve at runtime **does not crash and
does not warn.** SwiftUI skips the effect and draws the unmodified view, which
here is a flat grey tile and a plain mark - both entirely plausible. Compiling is
not evidence that either shader runs.

Neither state can be reached by waiting, either. The splash lasts exactly as long
as `restore()`, which against the demo catalogue is no time at all; and demo
covers are drawn on device in a frame or two, so the placeholder the ripple
exists for never survives long enough to photograph. Two DEBUG-only arguments
hold each state still:

- `-screen splash` renders `ConnectingView` directly, short-circuiting the
  session the way `-screen profile` already does.
- `-pendingCovers` makes every cover never resolve for the whole launch.

Shots `34-splash`, `35-covers-pending` and `36-dark-splash` are the result, and
they are the only thing in this project that can tell a working shader from a
silently skipped one.

## Consequences

**Two values were tuned against a screenshot rather than chosen.** The ripple's
first pair of greys was 7% apart on a white surface, which the falloff and the
breath cut to about 3 - the shot came back looking like the shader had failed to
load. And the shimmer at Beam's own 0.85 drove the mark's leading corner to
white, because Beam sweeps a logo with a transparent background while Sorty's
mark is a filled tile, so the same band washes the whole square. Both numbers
are commented with the measurement, not the preference.

**The splash keeps its accessibility label and loses its text.** "Connecting to
Spotify" is gone from the screen and retained as the accessible name. A sighted
listener gets a mark on a field for a beat; a VoiceOver listener would otherwise
get an unlabelled screen that silently waits.

**Two spinners survive, and the line between them and the four removed is worth
naming**, because "remove the loading indicators" read literally would take them
too. Both remaining ones sit on an action the listener *started*: saving an
arrangement (`TrackListView.saveGlyph`) and authorizing (`ConnectFlowView`'s
advance bar). Someone who has just pressed a button needs to know the press
landed, and the feedback answers a question they actually asked.

The four removed answered a question nobody asked. That is the test for anything
proposed here later: **did the listener do something, and are they waiting to
find out whether it worked?** If not, the screen should just fill.
