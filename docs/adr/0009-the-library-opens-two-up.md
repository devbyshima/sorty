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

The ticket instructs that "the first redesign removed a two-up grid for measured
reasons" and that "ADR-0001's reasoning should be read and then explicitly
answered rather than ignored". Half of that is right and the pointer is wrong,
which is worth stating because it sent one reading of this decision astray
before the code was checked.

**ADR-0001 says nothing about the library.** It removes the fifteen-column
*track table*, and `.scratch/ui-redesign/spec.md` does not discuss a grid
either. **The measurement is real, and it lives in a code comment**, at
`SortyKit/Models/LibraryView.swift:61-68`: the first redesign removed a two-up
grid because a list showed about seven playlists per screen against the grid's
four. So there *is* a prior finding to answer, it is about **density**, and it
is answered below rather than ignored.

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
identifier. Sorty's holds playlists and nothing else. A playlist cover is
either a four-up mosaic Spotify generated or something its owner made, and in
neither case does it identify the playlist. **The name does**, which makes the
name the thing the layout has to protect.

**The name is what breaks first.** `PlaylistTile` reserves two lines for it
(`PlaylistsView.swift:261-264`) so that tiles in a row share a baseline. At
115pt a footnote-weight name wraps hard, and the badge-and-owner line below it -
which after ADR-0008 may have to say *Can't open* - has less room still. At
179pt both fit.

**Density buys less here, which is the answer to the seven-against-four
measurement.** That count is correct and it is the case *for* the list, which is
why the list survives as a layout and why anyone who wants density has it. It is
not a case for three-up: three-up pays the legibility cost of a small cover
*and* still shows fewer playlists per screen than the list it lost to. The
density argument, followed honestly, ends at the list rather than at a tighter
grid. Beyond that, Spotify's library can hold hundreds of saved items, where a
Sorty library is one listener's own playlists, which is tens - so the scroll
being saved is small in absolute terms whichever grid wins.

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
