# 8. A playlist you don't own never opens

Date: 2026-08-08

## Status

Accepted, and amended twice on 2026-08-10.

[ADR-0017](0017-collaboration-is-a-fact-not-a-feature.md): the *Collaborative*
mark named in the consequences below no longer exists. What that consequence was
recording - that collaborative playlists are readable and stay fully supported -
is unchanged and is now the whole of it.

[ADR-0018](0018-spotifys-own-playlists-are-one-thing-sorty-cannot-open.md): the
pre-check no longer refuses Spotify's own playlists on an id prefix, which is the
consequence this decision itself flagged (*"a pre-check can be wrong where
Spotify is more generous than documented"*) coming due. Ownership is still
pre-empted, because ownership is a fact. The endpoint latch below is also
corrected: it is now set once per session rather than probed once per refused
playlist, and it reports the `/items` refusal rather than the fallback's.

## Context

Spotify's February 2026 Development Mode migration changed what an app may read.
Get Playlist Items is now, in Spotify's own words, "only accessible for playlists
owned by the current user or playlists the user is a collaborator of", and "a
`403 Forbidden` status code will be returned if the user is neither the owner nor
a collaborator of the playlist". The same migration renamed
`/playlists/{id}/tracks` to `/playlists/{id}/items` and, from 9 March 2026,
removed the old spelling for Development Mode apps entirely.

Every Sorty listener is a Development Mode app. That is not a phase the product
is passing through: a single application is capped at five authorised listeners,
which is exactly why each listener brings a Client ID of their own. There is no
version of Sorty in which this rule does not apply.

Three separate things followed from that, and all three reached the listener as
something other than what they were.

**Another listener's playlists disappeared from the library.** The listing drops
playlists with nothing in them, reading `tracks.total > 0`. Since February 2026 a
playlist's contents object is returned only for playlists the listener owns or
collaborates on, and the count lives inside it, so every other listener's
playlist now arrives with no count at all. Sorty defaulted the missing count to
zero and then filtered on it, so the playlists were not refused, or explained, or
marked: they were deleted before anything drew them.

**One unreadable playlist stopped the whole session loading.** A playlist Spotify
will not show anyone answers 404, which is also what a Client ID predating
`/items` answers. The service told those apart by trying the older spelling, and
it set the latch that remembers the answer on the way *into* the fallback rather
than on the fallback working. So opening one refused playlist left every later
request in the session pointed at an endpoint that no longer exists for a
Development Mode app, and the listener's own playlists stopped loading until
relaunch.

**The refusal, when it did arrive, said nothing useful.** A 403 became "access to
another listener's playlists is Spotify's to grant", which names no rule, no
date, and nothing the listener can do.

## Decision

**Sorty knows which playlists Spotify will open, and says so before the tap.**
`Playlist.contentsAreReadable(byUserID:)` holds the rule in one place: owned, or
collaborative, and neither Spotify's own nor algorithmic. The library marks what
fails it with a *Can't open* badge, which replaces *Read-only* on those rows -
telling someone Overwrite will be missing from a screen they can never reach is
noise in front of the fact that matters.

**Opening one costs no request.** `TrackListModel` checks the rule before asking.
Ownership arrived with the library listing, so the answer is already in hand, and
a request would spend one of a five-listener quota to be told 403. Only another
listener's playlist is pre-empted this way; Spotify's own editorial and
algorithmic playlists fail the same rule for a different reason and keep the
explanation `LoadFailure` gives them.

**It is an empty state, not an error.** A rule is not a failure, it offers no Try
Again, and `EmptyState.contentsWithheld` carries the words: what the rule is,
whose playlist it is, and the two ways out that exist - ask for a collaborator's
invite, or add the tracks to a playlist of your own. `LoadFailure` returns that
same sentence for the refusal arriving from the wire, so a listener who meets the
rule twice meets it in the same words.

**A count Spotify withheld is not a count of zero.** `Playlist.trackCountIsKnown`
records whether Spotify reported one, the library drops only what Spotify said
was empty, and a row whose count never arrived says *Track count hidden* rather
than inventing "0 tracks".

**The endpoint latch is set by evidence, not by intent.** The older spelling is
latched only once it has actually answered; when the fallback fails too, the
spelling was never the problem, the latch is put back, and the refusal reported
is the one from the endpoint the app means to use.

## Consequences

**Sorty cannot arrange another listener's playlist, and now says so plainly
instead of appearing to try.** No workaround exists at this quota tier. Reading
one through Spotify's public web pages would mean scraping an undocumented
endpoint, which is not something this app will do while it is also arguing, in
ticket 12, that it stays inside Spotify's rules.

**Collaborative playlists are the exception and stay fully supported.** They are
readable, they carry the *Collaborative* mark, and they remain read-only for
writes: ADR-0002 makes Overwrite replace the whole playlist, and doing that to
someone else's is not a thing to enable quietly, whatever the API permits.

**A pre-check can be wrong where Spotify is more generous than documented.** An
extended-quota app can read anything, and Sorty would refuse on its behalf. No
such app exists here, and the alternative is a doomed request and a spinner in
front of a sentence that was true on arrival.

**The demo catalogue gains a playlist owned by someone else and shared with
nobody**, with no track count, because the harness cannot photograph a state the
fixtures cannot reach.
