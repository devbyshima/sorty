# 19. A skeleton is the shape of what is coming, and the splash waits for one row

Date: 2026-08-10

## Status

Accepted. Amends [ADR-0015](0015-waiting-is-texture-not-status.md), which
removed four status readouts and left two screens with nothing at all. It is an
amendment rather than a replacement: 0015's rule stands, including the shader
boundary, which this restates rather than relaxes.

## Context

ADR-0015 stated its own test:

> **did the listener do something, and are they waiting to find out whether it
> worked?** If not, the screen should just fill.

On the track list, the listener *did* do something. They tapped a playlist. And
`TrackListModel` assigns `rows` once, when every page has landed - it does not
stream the way the library does - so what 0015 left there was
`Color.clear.frame(height: 1)`, and on a five-hundred-track playlist that is a
header floating over an empty field for several seconds with no evidence the tap
registered. "The screen should just fill" was written about a screen that fills
in two seconds. It does not describe this one.

The library is the weaker case and gets the weaker change. The grid genuinely
does fill, batch by batch, so 0015's reasoning holds for the part that has
arrived. What it never covered is the part that has not: a two-up grid showing
three of forty-seven playlists is not a library filling, it is a library that
looks finished and is wrong.

Separately, the launch. `ConnectingView` lasted exactly as long as
`session.restore()`, and `completeSignIn` sets `stage = .ready` and *then* awaits
the first page of playlists - so the splash came down onto an empty grid and the
library assembled itself in front of the listener.

## Decision

**Placeholders draw the shape of what is coming. They never draw a count.**

This is the line that keeps the amendment honest, and it is the whole of what
0015 was protecting: `PlaylistLoad.loading(loaded:total:)` now decides *how many
shapes to appear*, and nothing prints it. There is no "12 of 40" anywhere. 0015's
finding - that the number changed the character of a two-second fetch into an
operation with a status - is preserved exactly.

**Cover-shaped placeholders reuse `CoverRipple` unchanged.** It is already this
app's placeholder idiom, already verified by `35-covers-pending.png`, and already
on the right side of the compliance boundary. No new shader touches artwork; no
new shader touches a cover at all.

**Text-shaped placeholders are Swift, not Metal**, for three reasons in order of
weight. A `[[stitchable]]` function that fails to resolve is silently skipped and
SwiftUI draws the unmodified view - which on a text bar is a flat grey rectangle,
i.e. exactly what success looks like, so the failure mode and the success mode
are visually identical; 0015 built two screenshots to catch that on two shaders,
and twenty more call sites is more surface than the texture is worth.
`coverRipple`'s geometry is square-specific and stretches into extreme ellipses
on a 140×12 bar. And a directional shimmer sweeping a list says *thirty-eight
percent of the way there*, which is a status readout wearing texture's clothes -
the precise thing 0015 removed four of. A breath says "not yet".

The breath is `coverRipple`'s own, lifted out of Metal, so a placeholder cover
and the bars beneath it are visibly the same material.

**Placeholder geometry is taken from the real row, never guessed.** Heights come
from a hidden `Text` in the row's own font rather than a number, because every
tile this stands in for *reserves* its lines and a guessed height is a guaranteed
reflow at the handoff - which is the one thing this exists to prevent. The track
placeholder draws **no value column**, because the track list always opens in
`.originalOrder` and `TrackRowText.isAlreadyVisible` returns true for it, so the
real row has no value on arrival either.

**Library placeholders trail; they are never a screenful.** They stop entirely
once the library is complete, before the first page arrives (the splash is still
over the screen then), and while a search or a chip is narrowing the library -
shapes under a two-result search would promise results that are not coming.

**The splash holds until session restore, the first page of playlists, and a
floor of 700ms - whichever is latest - and can never outlast six seconds.**

The floor is **derived, not chosen**, and that distinction is what keeps it
compatible with `ConnectingView`'s own promise not to invent a wait. It is the
length of the `.spring(response: 0.75, dampingFraction: 0.58)` settle already on
screen; a splash torn off 120ms into it is not a screen anybody saw, it is a
flash of a half-scaled mark. The evidence that it is a floor rather than a brand
moment: **under Reduce Motion it is zero**, because `ConnectingView` skips the
settle there and there is nothing left to protect. A brand moment would apply in
both.

One real row, not the reported total - which arrives on the same response and
would be satisfied by one carrying no usable playlists - and not `.ready`, which
is every page of a library that might hold four hundred.

The ceiling is the only rule here whose absence would be a defect rather than a
regression, and it is safe to be as short as six seconds *because of* the
placeholders: the app releases into a library that now draws the shape of what is
coming instead of an empty grid. The timeout and the skeletons are one decision.

A signed-out launch releases immediately, floor and all. There is no account,
nothing to restore and no playlists to wait for, so holding a mark over the way-in
screen would be inventing a wait.

## Consequences

**Two spinners still survive, and they are still the only two.** The save glyph
and the connect flow's advance bar, both on user-initiated actions. No
placeholder is a spinner.

**The launch is longer by up to 700ms on a fast connection**, and shorter in the
only sense that matters: the library it uncovers has playlists in it.

**Every placeholder is hidden from VoiceOver, and each region says one thing
instead.** Without that a filling library is silent to a listener using
VoiceOver - a heading and then nothing, indistinguishable from an empty library.

**Two new harness arguments exist because these states are otherwise
unphotographable.** `-stallLibrary` holds pages back, for the same reason
`-pendingCovers` holds covers. What to check in the resulting shots is that
**nothing moves between a placeholder and its loaded twin**: same cover size,
same corner, same reserved lines, same row pitch. A placeholder whose geometry
drifts from the row it stands in for causes the reflow this decision exists to
prevent.

**The gate never re-arms.** Signing in again sets `stage` back to `.connecting`,
and a gate that re-armed on that would drop a full-screen splash over an app the
listener is already using.
