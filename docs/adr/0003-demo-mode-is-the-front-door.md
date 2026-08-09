# 3. Demo Mode is the front door

Date: 2026-08-05

## Status

Superseded by [ADR-0007](0007-connecting-is-the-front-door.md) on 2026-08-08.
Demo Mode is gone from the shipped app; the catalogue it made load-bearing
survives only as test and screenshot-harness scaffolding. The friction this
decision was written to avoid is real and is now accepted rather than solved -
see 0007's consequences.

## Context

Connecting a real Spotify account to Sorty requires the user to supply their
own Client ID. This is forced by Spotify: an application in development mode is
capped at five listeners, so a single Client ID shipped with the app would lock
out every user past the fifth. Lifting the cap requires extended quota, which
Spotify grants on evidence of 250k monthly active users - unreachable for an app
that cannot onboard its sixth user.

Obtaining a Client ID means leaving the app, creating a Spotify developer
account, registering an application, and copying a string back. The first UI put
that requirement in front of everything: *Connect Spotify* was the primary
action, an information card explained the cap, and the user was directed to
Settings to paste the ID. Demo Mode - which requires none of this, needs no
network, and exercises the entire product - was the secondary button.

The result is that the highest-friction moment in the product sits before any
demonstration of its value.

## Decision

Demo Mode is the state the app launches into. A first-run user is arranging a
playlist within seconds, against the built-in sample catalogue, with no account.

Connecting is repositioned as an upgrade, reached when the user wants to save
something - the one thing Demo Mode cannot do. At that point it is a guided
flow: why the Client ID is needed, a link out to the Spotify dashboard, paste,
verify. It is no longer a card pointing at another screen.

## Consequences

**Lost:** the shortest path for a user who arrived specifically to sort their own
playlists. They now pass through a demo they did not ask for, and the connect
affordance must be prominent enough that this is a beat rather than an obstacle.

**Gained:** the product demonstrates itself before asking for developer-account
work. The Client ID request arrives attached to a concrete motive - "save this
arrangement" - instead of as an upfront toll.

**`DemoCatalog` becomes load-bearing.** It is no longer a testing convenience; it
is the first impression. Its tracks need real artwork (`Playable.album.images`),
plausible audio features, and enough size to make an arrangement feel real. As of
this decision it contains a single `images:` reference, so every playlist renders
as a grey placeholder.

**Demo Mode's read-only boundary must be obvious rather than punitive.** A user
who arranges a demo playlist and reaches for Save should meet the connect flow,
not an error.
