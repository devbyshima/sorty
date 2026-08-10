# 18. Spotify's own playlists are one thing, and Sorty cannot open them

Date: 2026-08-10

## Status

Accepted. Amends [ADR-0008](0008-a-playlist-you-do-not-own-never-opens.md),
which held the readability rule and pre-empted more than it should have.

## Context

"Spotify's own playlists aren't being recognised" turned out to be three
separate defects wearing one symptom, and the first of them had been invisible
for a year because the fixtures agreed with it.

**The prefix never matched the playlist it was named after.** `isPersonalized`
read `id.hasPrefix("37i9dQZF")`. Discover Weekly's id begins `37i9dQZEVXc`;
Release Radar and On Repeat likewise; every chart is `37i9dQZEVXb`. The `37i9dQZF`
family is the editorial lists (`37i9dQZF1DX…`) and the Daily Mixes and radio
(`37i9dQZF1E…`). So the one playlist the predicate existed for had never once
satisfied it, and fell through to the `owner.id == "spotify"` branch, collecting
the editorial sentence instead of the "playlists Spotify makes for you" one.

It survived because **every fixture in this repository used
`37i9dQZF1DXcBWIGoYBM5M` - which is Today's Top Hits - with Discover Weekly's
name on it**: in `PlaylistRowTests`, `LoadFailureTests`, `LibraryViewTests` and
`DemoCatalog`. The tests and the code agreed with each other and with nothing on
Spotify. A demo catalogue that opened Discover Weekly perfectly, which is the one
thing no listener's Spotify will ever do, completed the picture.

**Playlists Spotify listed and would not describe were silently deleted.**
`/me/playlists` can carry a `null` where a playlist object should be.
`SpotifyMusicService` did `page.items.compactMap(\.self)`, so those entries went
before anything drew them - a deletion the listener could not see and could not
ask about. Their library simply held fewer playlists in Sorty than in Spotify,
which is the exact shape of the complaint.

**`owner.id == "spotify"` is not how Spotify publishes.** The charts and the
regional editorial desks use accounts of their own - `spotifycharts`,
`spotifyusa`, `spotify_uk_` and a long tail of the same shape - so a playlist of
theirs landed in `.other`, where the copy told the listener to ask whoever owns
it to make it collaborative. Nobody is going to ask Spotify to make RapCaviar
collaborative.

## Decision

**Sorty cannot make these playlists sortable, and this decision does not pretend
otherwise.** Spotify's announcement of 27 November 2024 lists *"Algorithmic and
Spotify-owned editorial playlists"* as its own restricted item, separately from
the browse endpoints it removed the same day, and only applications already
holding extended quota were unaffected. Every Sorty listener is a Development
Mode app by construction - a single app admits five listeners, which is why each
brings a Client ID of their own - and extended quota requires a registered
company with 250k monthly active users. There is no scope, no endpoint and no
fallback that changes this, and scraping is out on the principle ADR-0008 already
stated. What follows is therefore about *not losing them, not mislabelling them,
and saying the true thing*.

**Nulls are counted, not dropped.** `PlaylistListing` carries `withheldCount`
alongside the playlists, and the library reports it in a quiet line at the foot,
below the last row. Not a banner: it names a rule with no remedy, and a permanent
unactionable banner over the library is what `EmptyState`'s own rules argue
against. At the foot it is found by the person who went looking for the playlist
that isn't there and invisible to everyone else. **It offers no action**, because
there is no permission to grant and no button that would work, and offering one
would be the app pretending it had a way out.

The count is the directly observed nulls, not `page.total` minus what survived.
The listing's total is a count of a set that can change under a paged read, and
subtracting from it would invent a shortfall for anyone who made a playlist
mid-load.

**The stem widens to `37i9dQZ` and stops deciding anything expensive.** It is
folklore - Spotify documents none of it and could stop tomorrow - so it now
decides only two things, both safe to be wrong about: whether Overwrite is
offered, and which sentence a refusal gets. Nothing that costs a request rests on
it.

**`isSpotifyOwned` is the stem or an `owner.id` beginning "spotify".** A prefix
rather than a published list, because there is no published list and a new
regional account would silently rejoin `.other`. The cost is bounded and stated:
a listener whose own account id begins "spotify" is filed under the Spotify chip
and given Spotify's sentence instead of their name, and nothing they can open
stops opening, because what opens is decided by ownership alone.

**`.personalized` merges into `.spotify`.** The case existed only to pick between
two `LoadFailure` sentences, and it picked with a prefix already proved wrong
about the playlist it was named after. Widening the stem fixes Discover Weekly
and breaks Top 50 Global, which would then be told Spotify makes it personally. A
distinction the app cannot draw reliably is one it should stop pretending to
draw: one case, one sentence naming both kinds.

**`contentsAreReadable` is the documented rule and nothing else** - owner, or
collaborator. Both extra clauses were removed. The owner check was redundant
(Spotify is not you, so ownership already refuses it) and the prefix check was
wrong for the one Client ID old enough to read these, which is exactly the
grandfathered ID `FeatureSourceMode.spotify` already exists for.

**The pre-check keeps its existing split, and this is the correction to
ADR-0008.** Only another listener's playlist is pre-empted, because ownership is a
*fact* that arrived with the listing and a request there spends quota to be told
what is already in hand. Spotify's own is an *inference*: it almost certainly
refuses, and "almost certainly" is not something to refuse on Spotify's behalf.
ADR-0008 listed this as a known consequence - *"a pre-check can be wrong where
Spotify is more generous than documented"* - and this is that consequence coming
due.

**The legacy `/tracks` probe is asked once per session, not once per playlist,
and reports the right error.** ADR-0008 un-latched a failed probe so one
unreadable playlist could not poison the session, which was right and is kept;
what it also threw away was what the probe had just proved, so a library holding
twelve unopenable playlists spent twelve requests proving the same thing twelve
times. And the refusal reported is now the `/items` one rather than the 403 from
a spelling this app does not use, which names a rule that is not the one
refusing. The write path always did this; the read path said it did and did not.

## Consequences

**A listener who follows Discover Weekly now sees a number instead of a gap.**
That is the whole of the improvement, and it is worth being plain that it is not
what they wanted: they wanted to sort it. The honest form of that answer is a
sentence naming the rule and its date, which the FAQ, the library footer and
`LoadFailure` now all give in the same words.

**Three fixtures changed and one gained a rule.** `DemoCatalog` carries Discover
Weekly's real stem, a chart playlist under `spotifycharts`, and a stated
`withheldFromListing` count - an array cannot hold a hole, so the number has to
be declared for the footer to be photographable at all. `DemoMusicService` now
refuses what Spotify refuses, so the failure a listener is most likely to meet is
finally reachable from the harness.

**One assertion inverted on purpose.** `OtherListenersPlaylistsTests` used to
require that an algorithmic playlist Spotify reports the listener as owning be
refused. It now requires the opposite, with the reasoning in the message, because
the alternative is refusing on folklore in the one case where Spotify might say
yes.

**The `37i9dQZ` stem will eventually be wrong.** It is undocumented and it has
already been wrong once. When it breaks, what breaks is a sentence and an
Overwrite button, not access - which is precisely why nothing expensive was left
resting on it.
