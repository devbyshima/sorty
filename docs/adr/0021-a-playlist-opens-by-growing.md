# 21. A playlist opens by growing out of the tile you touched

Date: 2026-08-13

## Status

Accepted, and refined by
[ADR-0024](0024-the-zoom-grows-from-the-cover.md), which moves the source from
the whole tile to the cover inside it.

## Context

Opening a playlist was a stock push: the track list slid in from the trailing
edge while the library slid out. That is the right transition for a hierarchy of
*lists* - Settings to Audio features, where the thing you tapped was a line of
text and there is no geometry worth carrying across - and the wrong one here.

The library is a grid of covers. The track list opens on the same cover, centred
and 260pt wide, with the same name under it. The two screens already share their
subject and their largest object; a horizontal slide asserts they are two
different places and throws away the one continuity the layout had been building.

## Decision

**The playlist route, and only the playlist route, takes
`.navigationTransition(.zoom(sourceID:in:))`.**

The source is the whole tile - cover, name and owner - rather than the artwork
alone, so what grows is the target the finger actually hit. Both library layouts
carry it, so a grid tile and a list row behave the same way.

> **Superseded by ADR-0024.** The source is now the cover alone. A tile is mostly
> text, and unfolding a portrait rectangle of text into a screen threw away the
> one element the two screens genuinely share.

**The namespace is declared in `RootView`, not in `PlaylistsView`.** A
`.matchedTransitionSource` and the `.navigationTransition` it pairs with have to
share one namespace, and the two live on opposite sides of the
`navigationDestination` closure - the source is a tile in the library, the
destination is built at the root. A namespace declared in the library cannot be
seen from the closure that builds the destination, so it is declared where both
can reach it and handed down.

**No other route takes it, and no other route should.** Settings, the FAQ,
Credits and the Spotify app screen are all text rows leading to text screens. A
zoom there is motion applied for its own sake, and it would also break the one
thing the chrome currently makes legible: the root settings page wears a large
title and its sub-pages wear the inline bar, so depth is readable without
animation.

## Consequences

**There is no Reduce Motion branch, and its absence is deliberate.** `.zoom`
degrades to a cross-fade on its own when the setting is on, which is the reduced
form every other transition in this app already falls back to. A hand-written
branch would only restate it.

**The screenshot harness now has a state it can land in the middle of.** A
`-screen tracks` shot arrives through the zoom, so a capture taken too early
photographs the track list part-scaled with the library still visible behind it -
which is what happened on the first run after this landed, and which looks enough
like a rendering fault to be worth naming here. `SETTLE` covers it at its default
of 4 seconds; a slower machine needs the same bump it already needed for
everything else.

**A withheld playlist zooms too.** It opens onto the "can't open" state rather
than a track list (ADR-0008), and it still grows from its tile, because what the
transition promises is *this playlist* and not *this playlist has tracks*.
