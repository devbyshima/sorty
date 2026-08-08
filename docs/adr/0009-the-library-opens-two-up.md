# 9. The library opens two-up

Date: 2026-08-08

## Status

Accepted.

## Context

`.scratch/ui-redesign-2/issues/05-home-screen.md` asks the library to be rebuilt
against `references/spotify-library.png`, which shows a **three-column** grid of
covers. It was built with a **two-column** default, three-up and list reachable
from the menu (`LibraryLayout`). This records why, because the repo rule is that
reference designs are matched exactly and a deviation has to be argued rather
than shipped quietly.

The ticket also instructs that "the first redesign removed a two-up grid for
measured reasons" and that "ADR-0001's reasoning should be read and then
explicitly answered rather than ignored". **That reasoning does not exist.**
ADR-0001 is about removing the fifteen-column *track table*; it says nothing
about the library's layout, and neither does `.scratch/ui-redesign/spec.md`. So
there is no prior decision to answer and no measurement to overturn. The choice
is made here on its own merits, and the ticket's premise is corrected rather
than deferred to.

What the two layouts actually are, at a 402pt screen with the shipped 16pt
margins and 12pt gutters:

- Three-up: covers about **115pt** wide.
- Two-up: covers about **179pt** wide.

## Decision

**The library opens two-up. Three-up stays, one tap away, as a layout the
listener can choose.**

Three arguments, none of which apply to the reference:

**The reference's library is not this library.** Spotify's holds albums,
artists, podcasts and downloads - overwhelmingly commercial artwork,
commissioned to be legible at thumbnail size, where the picture *is* the
identifier. Sortify's holds playlists and nothing else. A playlist cover is
either a four-up mosaic Spotify generated or something its owner made, and in
neither case does it identify the playlist. **The name does**, which makes the
name the thing the layout has to protect.

**The name is what breaks first.** `PlaylistTile` reserves two lines for it
(`PlaylistsView.swift:261-264`) so that tiles in a row share a baseline. At
115pt a footnote-weight name wraps hard, and the badge-and-owner line below it -
which after ADR-0008 may have to say *Can't open* - has less room still. At
179pt both fit.

**Density buys less here.** Spotify's library can hold hundreds of saved items,
so fitting a third more per screen is real. A Sortify library is one listener's
own playlists, which is tens. The scroll saved is not worth the legibility
spent.

## Consequences

**The screen no longer matches its reference at first sight**, which is the cost
and is accepted. The reference layout is not lost, only not the default: the
menu offers two-up, three-up and list, and the choice persists.

**A listener with many playlists has a longer scroll by default.** The layout
control is in the overflow menu rather than on the screen, so they have to find
it. That is the same placement question ticket 05's other deviation raises, and
if the sort and layout controls ever move onto the screen this becomes cheaper
to answer rather than harder.

**If reopened:** the argument for three-up is that a listener who knows their
own playlists by their covers is scanning, not reading, and for them the name is
noise. That listener exists. If enough of them do, the answer is not to change
the default but to remember the last layout chosen, which is a smaller change
than this decision and does not require reversing it.
