# 10. The track row shows no position number

Date: 2026-08-08

## Status

Accepted. Reverses an instruction in
`.scratch/ui-redesign-2/issues/04-arrangement-header.md`.

## Context

Track rows carried a leading number: 1, 2, 3 down the list, showing where each
track landed in the applied Arrangement. It is gone from the row and still
spoken to VoiceOver.

Ticket 04 forbade exactly this. Describing what maps onto Sortify from
`references/spotify-playlist.png`, it says the position number and the
Arrangement's value with its bar are things "which the reference has no
equivalent for and which must not be dropped: they are the product."

The instruction was overtaken by the layout it was written for. The rebuild put
a large centred cover at the top of the screen and artwork on every row, and a
number column ahead of that artwork means the rows start at a different left
margin from the cover, the name, the description, the chips and the notice above
them. Everything on the screen lines up except the thing there is most of.

## Decision

**The number column is removed from the row. The position is still announced.**

The ticket's sentence bundles two things that are not equally load-bearing.

**The value and the bar are the product.** "128" against a bar showing where 128
sits between this playlist's slowest and fastest track is information that
exists nowhere else in Spotify and is the entire reason to open this screen.
Both stay, untouched.

**The ordinal is not.** It is the row's own place in a list the listener is
looking at, and a sighted reader takes it from the sequence. Printing 1, 2, 3
beside rows that are already in that order restates the layout. It cost a
column, and it bought a number that the position it occupies already tells you.

**Where sequence is not perceivable, the number stays.** VoiceOver reads rows one
at a time with no sense of the whole, so `TrackRowText` still opens its sentence
with the position: "3. Iron Letters by Vera Ash. BPM 188."
(`SortifyKit/Sorting/TrackRowText.swift`). Rank in an ordered list is real
information; the row simply is not where a sighted reader needs it drawn.

Unrankable tracks were already passed no position at all, in either
presentation, because numbering something the Arrangement could not place would
imply a rank it does not have. That rule is unchanged.

## Consequences

**Every row now starts at the same left margin as everything else on the
screen.** Artwork, cover, title, chips and notice share one edge.

**A listener cannot cite a track's rank without counting.** "The fourteenth
track" now requires counting rows. Nothing in Sortify asks anyone to do that -
there is no jump-to-position, no numbered reference anywhere else in the app,
and the save writes an order rather than a numbered list.

**The count moved rather than vanished.** How many tracks there are is in the
header, beside the owner and the running time, where it describes the playlist
instead of the row (ADR-0009's sibling change, `PlaylistHeaderText`).

**If reopened:** the case for the number is an Arrangement whose values are
mostly equal or mostly missing, where the sequence carries information the
values do not. Artist separation is the closest thing to that, and it prints no
value at all. If numbering is ever restored it should be restored *there*, for
that reason, and not down the whole list for consistency's sake.
