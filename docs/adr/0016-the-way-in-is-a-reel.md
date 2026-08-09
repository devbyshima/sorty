# 16. The way in is a reel, and the connect flow stands under a glyph

Date: 2026-08-09

## Status

Accepted.

## Context

Sorty's onboarding is two screens and `CONTEXT.md` is explicit that they are one
thing: the way-in screen, and the connect flow whose four steps *are* the
onboarding - "the two words name one thing".

Both were built to be read rather than to be arrived at. The way-in screen was a
mark, a title, a tagline and three points in a bulleted list. The connect flow
was a spine, then left-aligned prose, four times, distinguishable only by reading
it.

The instruction was to bring both closer to Beam
(`~/Dev/apps/beam/Apps/iOS/BeamiOS/OnboardingView.swift`), whose onboarding is
already the reference the splash was rebuilt against in ADR-0015.

## Decision

**The way in is Beam's reel. The connect flow keeps its structure and adopts
Beam's posture.**

- **`OnboardingReel`** ports Beam's `LoopOnBoarding`: three staggered pulse rings
  behind a symbol that bounces in time with them, the value props pushing up and
  blur-replacing beneath, phases advancing on a `TimelineView`.
- **`SignedOutView`** puts the three points through it, over `SplashBackdrop` -
  the same bloom the splash rises from, so launch and way-in read as one screen
  continuing rather than two screens meeting.
- **The connect flow** gains that backdrop, a per-step glyph, centred type, and a
  button that floats rather than sitting on a bar.

## What was deliberately *not* taken from Beam

Three things, because "similar to Beam" is not "identical to Beam" and the
differences are the interesting part.

**The four-step spine stays.** Beam has no equivalent - its stages simply
succeed one another. Sorty cannot afford that: it is about to ask someone to
register a developer application, and the spine's whole job is to show *the
shape of the ask before any of it is asked*. Removing it to match Beam would
have removed the one thing that makes four screens tolerable.

**The navigation title goes, but Back and Not Now stay.** Beam's onboarding
screens carry no chrome and offer exactly two buttons. Sorty needs three
affordances - advance, go back, and leave - because ADR-0007 made connecting the
only way in, and a modal nobody can escape is a worse first impression than the
way-in screen. So the toolbar survives with its title dropped: "Connect Spotify"
above "Sorty needs your own Spotify app" was the same sentence twice.

**No pulse rings on the connect steps.** Beam puts them on the screen that is
*searching* - actively scanning the network, with the rings saying so. Sorty's
last step is not searching; it is a button waiting for a finger. Rings there
would claim the app is working while it is idle. The one moment that screen
genuinely waits is after the tap, and the advance button already carries a
spinner for it (ADR-0015's test: did the listener do something, and are they
waiting to find out whether it worked?).

## Reduce Motion gets the old screen back

The reel does not run, and `SignedOutView` shows the three points as a still
list instead - which is exactly what this screen was before today.

This is not laziness about the reduced path, it is the honest reading of it. A
reel with its animation removed is still three lines of text replacing each other
on a timer, which is still movement, and it still hides two thirds of the content
behind a wait. Someone who has asked for less motion should not have to wait
nine seconds to learn what the app does. So the reduced form is not a quieter
reel; it is no reel.

## The bug this cost, and why it is worth writing down

The first build clipped the value props and the Connect button off both edges of
the display, and the cause was a piece of Beam I had "cleaned up".

Beam draws its pulse rings inside `Rectangle().foregroundStyle(.clear).overlay
{ … }`, which looks like a redundant wrapper. It is not. **A ring grows to twelve
times its own size - about 600pt - and a laid-out view that wide sizes everything
above it.** The reel became 600pt across, then so did the screen's stack, and
every child was laid out to a width half of which was off-screen. An overlay
never reports a size to its parent; a `ZStack` sibling does.

The same rule caught `SplashBackdrop`, whose blurred circle is also far wider
than the screen: it belongs in `.background { }`, never as a stack sibling. Both
call sites now say so in a comment, because the wrapper reads as noise and will
invite the same simplification again.

The general lesson: **in a ported layout, the odd-looking wrapper is load-bearing
until proven otherwise.** Beam's author did not write `Rectangle().overlay` for
fun.

## Consequences

**The app's name no longer appears on the way in.** The reel replaced the title
and tagline, as Beam's does. The mark carries identity, and the name is on the
icon the listener just tapped. If that turns out to be wrong, the reel is not
what needs undoing - a title above it is.

**One shot was added**, `37-connect-authorize`. The last step was the only one of
four the set never photographed, which is how it went unnoticed that it had
nothing to distinguish it from step three. It is appended rather than filed
beside `11`-`13`, because inserting it there collided with `14-playlists-two-up`
and would have renumbered half the set for one addition - the same reason the
withheld shots sit at the end.

**`padding(.top, 76)` on the flow's content is a measurement**, not a margin.
Dropping the navigation title raised the spine into `TopBlur`'s band - 44pt solid
plus a 20pt fade - and a smeared progress track reads as a rendering fault on the
one element whose whole job is to be legible at a glance.
