# 1. Arrangements replace the column table

Date: 2026-08-05

## Status

Accepted. Supersedes the design reasoning recorded in the comment at
`Sortify/Views/TrackTableView.swift:115`.

## Context

Sortify's first UI reproduced SortYourMusic's fifteen-column table on a phone.
The columns are fixed-width and sum to roughly 1,352pt (`SortColumn.width`),
against a 402pt screen — about 3.4 screens of horizontal scrolling.

The design defended this deliberately. The comment at `TrackTableView.swift:115`
reads: *"A genuine 15-column table, scrolled horizontally rather than collapsed —
the whole point of the app is comparing attributes side by side, and hiding
columns behind a picker would lose that."* To mitigate the width, selecting a
column auto-scrolls it into view (`TrackTableView.swift:152`).

That mitigation has a hole. Once a numeric column is centred, Title and Artist
have scrolled off the left edge — the screen showing the app's entire value
proposition stops saying which track each row is. `screenshots/04-tracks-bpm.png`
shows the failure directly: a grid of bare numbers with no identity.

The column metaphor also forced two things into it that aren't attributes.
`.asep` (artist separation) and `.rnd` (shuffle) are algorithms that rearrange a
playlist, not properties a track has, and both set `directionMatters: false`
(`SortColumn.swift:84`). They render as columns of meaningless values, and
re-tapping their header means something different from re-tapping BPM's —
"re-roll" versus "flip direction" (`SortColumn.swift:146`).

## Decision

The table is removed. Its replacement is built on **arrangements**: a named way
of ordering a playlist, with attribute-derived orderings and computed ones as
peers (see `CONTEXT.md`).

- A track row shows artwork, title, artist, the active arrangement's value, and a
  bar positioning that value within the playlist's range for that attribute.
- Arrangements are chosen from a pinned chip row of five plus a `More` chip that
  opens a picker sheet, where each arrangement carries its explanation.
- Direction is a modifier shown on the active chip. Shuffle gets its own re-roll
  affordance rather than overloading the direction gesture.
- Save is the screen's primary action and holds the nav bar alone.

## Consequences

**Lost:** side-by-side comparison of several attributes for the same track. A
user who wants to see BPM, energy and valence together must now open a track
detail rather than reading across a row. This is the real cost of the decision
and was accepted knowingly — the screen is for producing an order, not for
browsing a matrix.

**Gained:** track identity is never scrolled away. Artwork (`Playable.album.images`,
present in the model and previously unused) becomes the primary identity cue.
Attributes and algorithms stop pretending to be the same kind of thing. The
explanation copy in `SortColumn.explanation`, previously reachable only from the
FAQ, surfaces at the moment of choosing.

**If reopened:** the argument for the table is that comparison across attributes
is a real job. Should that job return, it belongs on iPad or in a landscape
presentation with room for it — not in a 402pt-wide portrait scroll.
