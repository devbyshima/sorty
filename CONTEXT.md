# Sortify

Sortify reorders a Spotify playlist by the musical character of its tracks -
tempo, energy, mood - and saves the result back to Spotify. It reads a playlist,
produces a new order, and commits it.

## Language

### What the user produces

**Arrangement**:
A named way of ordering a playlist's tracks, and the first-class thing a user
picks. Both attribute-derived orderings (`By BPM, fastest first`) and computed
ones (`Artist separation`, `Shuffle`) are arrangements - they are peers, not
different kinds of thing.
_Avoid_: Sort, sort column, sort order

**Attribute**:
A property a track has - its BPM, energy, danceability, loudness, valence,
acousticness, popularity, length, release date, date added. An attribute is
something a track *is*; an arrangement is something you *do* to a playlist. Most
arrangements are derived from one attribute, but an attribute is not itself an
arrangement.
_Avoid_: Column, field, metric

**Basis**:
An arrangement with its direction stripped off - what stays the same when you
flip `By BPM, fastest first` to `By BPM, slowest first`. It is what the user
means by "which arrangement is selected", and so what a chip is. Always derived
from an arrangement, never stored next to one: the app holds exactly one piece
of ordering state, and a stored basis would be a second.
_Avoid_: Sort key, mode, kind

**Artist separation**:
An arrangement that spaces tracks by the same artist as far apart as possible.
Computed by Sortify, not read from any track.
_Avoid_: A.Sep, artist spacing, de-clumping

### Where the data comes from

**Audio features**:
The subset of attributes that come from an external analysis provider rather
than from Spotify's own track metadata - BPM, energy, danceability, loudness,
valence, acousticness. These can be missing for a track; Spotify's own metadata
never is.
_Avoid_: Analysis, audio analysis, track features

**Demo Mode**:
A run against the built-in sample catalogue, with no account and no network.
**Not a state a listener can reach.** ADR-0007 removed it from the shipped app;
it survives under `#if DEBUG` as the fixture layer for the tests and the data
source for the screenshot harness, entered only by the `-demo` launch argument.
Read-only - a Demo Mode arrangement can be produced but never saved.
_Avoid_: Sample mode, offline mode, guest mode

**Signed out**:
The state the app is in until a Spotify account is connected, and where signing
out lands. The way in, not an error: it names what Sortify does and offers the
connect flow. ADR-0003 refused to have one at all; ADR-0007 makes it the front
door.
_Avoid_: Logged out, unauthenticated, welcome

**Connect flow**:
The four steps that turn a listener with no account into one with a working
session: why their own Client ID is needed, creating the app, pasting the ID,
authorizing. It is Sortify's **onboarding** and the two words name one thing -
there is no separate first-run sequence, and there is nothing else to collect,
because a Client ID and an authorization are the whole of what this app needs
from anyone. Reached from the signed-out screen, from Save without an account,
and from the account menu; the Client ID stays editable in Settings afterwards.
Under ADR-0003 it was on demand and not a gate. ADR-0007 made it the way in.
_Avoid_: Onboarding, sign-up, setup wizard, first run

**Withheld**:
What Spotify does with a playlist the listener neither owns nor collaborates on:
it names the playlist and refuses its contents, and sends no track count either.
Not an error, not a private playlist, and not an empty one, all of which it
resembles from inside the app. A withheld playlist still appears in the library,
marked *Can't open*, and opening one costs no request because ownership arrived
with the listing. ADR-0008.
_Avoid_: Forbidden, blocked, inaccessible, restricted

**Client ID**:
The identifier of a Spotify developer application, which in Sortify each user
supplies for themselves. Spotify caps a single application at five listeners, so
one shared Client ID would lock out every user past the fifth - the requirement
is a consequence of that cap, not a preference.
_Avoid_: API key, app key, token

### How the app presents itself

**Appearance**:
Whether Sortify is drawing itself light or dark. Followed from the device by
default and overridable by the user. Both are first-class: neither is the real
design with the other derived from it.
_Avoid_: Theme, mode, dark mode, colour scheme
