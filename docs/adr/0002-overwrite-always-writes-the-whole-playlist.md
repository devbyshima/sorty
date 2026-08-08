# 2. Overwrite always writes the whole playlist

Date: 2026-08-05

## Status

Accepted.

## Context

`TrackTableModel.save(createNew:)` builds its payload from `arrangedRows`
(`TrackTableModel.swift:215`), which is the list *after* the BPM filter has been
applied. The only guard is that the result is non-empty (`:216`).

That makes overwrite destructive in a way nothing on screen communicates. A
68-track playlist narrowed to 20 by a tempo filter, saved with *Overwrite This
Playlist*, is replaced on the user's real Spotify account with those 20 tracks.
The other 48 are gone, and Spotify offers no undo. The menu item carries
`role: .destructive` (`TrackTableView.swift:184`), which colours the label red
and asks for no confirmation.

The behaviour is not purely a mistake - filtering to a tempo range and keeping
the result is a real workflow, and it is exactly right when the destination is a
*new* playlist.

## Decision

The two operations are separated by what they are allowed to write:

- **Overwrite** always writes every track in the playlist, reordered by the
  active arrangement. The filter is a view onto the arrangement and never
  narrows what overwrite writes.
- **Save as new playlist** may write a subset. When a filter is active this is
  stated in the action itself - "Save these 20 as a new playlist".

Destructive loss is therefore prevented structurally, not by a warning dialog.

## Consequences

**Lost:** pruning a playlist in place. Someone who wants a playlist to *become*
its 170–180 BPM subset must create the new playlist and delete the old one
themselves, in Spotify.

**Gained:** no sequence of taps in Sortify can remove a track from an existing
playlist. That invariant is worth more than the workflow it costs, because the
failure is silent, immediate and unrecoverable.

**Do not revert by convenience.** Passing `arrangedRows` to both paths looks like
a harmless simplification and reintroduces the data loss. If overwrite ever
needs to write something other than the full track set, that is a decision to
revisit here first.
