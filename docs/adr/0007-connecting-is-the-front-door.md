# 7. Connecting is the front door

Date: 2026-08-08

## Status

Accepted. Supersedes [ADR-0003](0003-demo-mode-is-the-front-door.md).

## Context

ADR-0003 made Demo Mode the state the app launches into, on the reasoning that
Spotify's five-listener cap forces every user to supply their own Client ID, and
that putting the highest-friction moment in the product before any demonstration
of its value was the wrong order. That reasoning was sound and is not disputed
here. What changed is what the product is for.

Sorty arranges *your* playlists. Everything the demo catalogue demonstrates -
an arrangement being produced, a position bar, a track's readings - it
demonstrates against seven invented playlists by invented artists, which no one
came here to reorder. The one thing Demo Mode cannot do is the thing the app
exists for: save an arrangement back. So the demonstration always ends at the
same wall, and the listener arrives at the Client ID requirement anyway, having
first spent time on music that was never theirs.

Demo Mode also had a second life it was never designed for. It is the fixture
layer for 7 test files and the data source for 29 of the 30 screenshots the
harness takes - every one except the way-in screen itself. That role is
genuinely load-bearing and is not in question.

## Decision

**Demo Mode is removed from the shipped app.** There is no sample catalogue in a
release build, no way to choose it, and no state the app falls back into when an
account is unreachable. Connecting a Spotify account is how Sorty starts.

**The demo catalogue survives as scaffolding.** `DemoCatalog`,
`DemoMusicService`, `DemoArtwork` and the demo feature provider stay in the
repository, compiled under `#if DEBUG`, where the test target and the screenshot
harness both reach them. `SortyKit` is compiled into both the app and the
hostless test target, and `DEBUG` is defined by Xcode's own default for the Debug
configuration and empty in Release - the project does not set
`SWIFT_ACTIVE_COMPILATION_CONDITIONS` itself. So one conditional serves all three
consumers and excludes the whole of it from Release.

The listener-facing consequence of this is that Sorty now has a signed-out
state, which ADR-0003 explicitly removed. The connect flow is no longer an
upgrade reached from Save; it is the way in.

## Consequences

**Lost:** the ability to evaluate Sorty without a Spotify developer account.
The friction ADR-0003 identified is real and is now unmitigated - a new listener
meets "create a developer application and paste a Client ID" before seeing
anything work. Anyone who is not already committed will not get past it. This is
accepted knowingly: the product is for arranging your own library, and a
demonstration against a stranger's invented playlists was not buying enough to
justify a second front door and a second set of copy.

**Gained:** one path through the app instead of two. Every screen had a Demo Mode
branch - a read-only notice, a Save that opened the connect flow instead of
saving, a fallback when an account could not be reached, a picker in Settings -
and each of those was a second thing to design, word and keep true.

**The guided connect flow becomes the first impression**, so its four steps carry
weight they did not before. Whatever ADR-0003 gained by attaching the Client ID
request to a concrete motive is gone; the flow has to be persuasive on its own.

**The harness now depends on a debug-only seam** rather than on a state the app
can genuinely enter. If that seam breaks, 18 screenshots silently photograph an
empty or signed-out library rather than failing loudly. That is a real hazard and
is the reason the seam is a named launch argument rather than an inferred
fallback.
