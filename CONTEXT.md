# Sortify

Sortify reorders a Spotify playlist by the musical character of its tracks —
tempo, energy, mood — and saves the result back to Spotify. It reads a playlist,
produces a new order, and commits it.

## Language

### What the user produces

**Arrangement**:
A named way of ordering a playlist's tracks, and the first-class thing a user
picks. Both attribute-derived orderings (`By BPM, fastest first`) and computed
ones (`Artist separation`, `Shuffle`) are arrangements — they are peers, not
different kinds of thing.
_Avoid_: Sort, sort column, sort order

**Attribute**:
A property a track has — its BPM, energy, danceability, loudness, valence,
acousticness, popularity, length, release date, date added. An attribute is
something a track *is*; an arrangement is something you *do* to a playlist. Most
arrangements are derived from one attribute, but an attribute is not itself an
arrangement.
_Avoid_: Column, field, metric

**Artist separation**:
An arrangement that spaces tracks by the same artist as far apart as possible.
Computed by Sortify, not read from any track.
_Avoid_: A.Sep, artist spacing, de-clumping

### Where the data comes from

**Audio features**:
The subset of attributes that come from an external analysis provider rather
than from Spotify's own track metadata — BPM, energy, danceability, loudness,
valence, acousticness. These can be missing for a track; Spotify's own metadata
never is.
_Avoid_: Analysis, audio analysis, track features

**Demo Mode**:
A run of the app against a built-in sample catalogue, with no account and no
network, and the state the app starts in. Read-only — a Demo Mode arrangement
can be produced but never saved.
_Avoid_: Sample mode, offline mode, guest mode

**Client ID**:
The identifier of a Spotify developer application, which in Sortify each user
supplies for themselves. Spotify caps a single application at five listeners, so
one shared Client ID would lock out every user past the fifth — the requirement
is a consequence of that cap, not a preference.
_Avoid_: API key, app key, token
