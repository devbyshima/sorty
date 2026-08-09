# 12. The cover keeps its lean and loses its sheen

Date: 2026-08-08

## Status

Accepted. Resolves `.scratch/ui-redesign-2/issues/07-cover-touch-interaction.md`.

## Context

`StickerCover` makes both covers behave like a sticker: it presses in under a
fingertip, leans away from it, carries a highlight that stays put while the
surface turns, and springs flat with a little overshoot. It is used on the
playlist screen (`TrackListView.swift:247`) and in the track sheet
(`TrackDetailSheet.swift:64`), which means it is applied to Spotify's artwork.

Ticket 07 carried a constraint added from ticket 12, warning that a Metal shader
deforming that artwork would be distortion and telling whoever built it to raise
the question first. **The shader was never built. `StickerCover` shipped
instead, and nobody checked the warning against it.** Spotify's design
guidelines, quoted in this effort's own research:

> Don't overlay images or text on top of the artwork.

> Artwork must be kept in its original form. Don't animate or distort it in any
> way. This includes applying overlays and blurring.

The effect did two of the named things: a `RadialGradient` highlight blended
`.plusLighter` over the cover, and a `scaleEffect` plus two `rotation3DEffect`s.

Two facts bear on the judgement and neither removes the problem. At rest the
artwork is untouched, because the highlight's opacity is zero unless pressed and
the lean springs back, so both appear only while a finger is down. And Reduce
Motion already disabled the whole effect, which meant a compliant rendering
already existed in the codebase as a branch.

## Decision

**The sheen goes. The lean stays.**

The highlight was the clearest breach of the two: it is unambiguously an overlay
on the artwork, and the guideline names overlays twice. It is now gone from the
view, and `StickerTilt` lost the point it travelled to, because a number nothing
reads is not worth keeping and this repo deletes rather than archives. One test
went with it.

The lean stays, and **that is a deliberate, accepted residual risk rather than a
clean result.** Ticket 07 said so when it listed this option: it "does not answer
'don't animate it in any way'". A `rotation3DEffect` under a finger is animation
of the artwork on the plain reading. It is kept because it is the whole of what
makes the cover feel like an object rather than a picture, it is transient, it
never alters a pixel of the image itself the way an overlay or a blur does, and
it reverts completely.

## Consequences

**The lean reads flatter than it did.** The highlight was what sold the surface
as physical; without it the cover is a rectangle rotating in perspective, which
is a weaker effect and an honest cost of the decision.

**Sorty still animates Spotify's artwork under a finger**, and if that is ever
challenged the answer is this ADR rather than a discovery. It joins the two
items ticket 12 already put on the same list: the near-identical name and the
near-identical screens, which Apple's Guideline 4.1(a) treats as one test. This
is the third.

**No shader will be added on top of this without reopening the question.** Ticket
01 established the mechanics and ticket 07 is now closed, so anything that
deforms or samples the cover is a new decision, not a continuation of one.

**Reduce Motion is unchanged** and still removes the effect entirely, which after
this decision is a smaller difference from the default rendering than it was.

**If reopened:** the case for dropping the lean too is that it is the last thing
standing between Sorty and a clean reading of the guideline, and that the
effect it protects is decorative by this ticket's own finding - it encodes no
Attribute. If the naming question is ever resolved in favour of a rename, this
is worth revisiting at the same time, because the three risks compound.
