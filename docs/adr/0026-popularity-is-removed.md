# 26. Popularity is removed

Date: 2026-08-13

## Status

Accepted. Reduces the Attribute set fixed by
[ADR-0004](0004-original-order-is-a-name-not-a-case.md) from thirteen to twelve.

## Context

Arranging by Popularity ranked nothing. Every track landed in the unrankable
group, and the detail sheet read "Unavailable" for the value.

The cause is not in this app. **Spotify removed `track.popularity` from the API
in February 2026**, in the same change that renamed `/playlists/{id}/tracks` to
`/playlists/{id}/items` and withdrew batch `GET /albums`. The removal applies to
newly registered applications - which is every application Sorty asks a listener
to create, because a development-mode app admits five listeners and so cannot be
shared. `Playable.popularity` decoded to `nil` for every track, for everyone.

Release date met the same fate in the same release and survived, which is the
comparison worth making. A track's own album still carries `release_date`, so
there was a second place to read it from and
`ReleaseDateSourceTests` now pins that independence. Popularity has no second
place. It is not derivable from anything else the API sends, and the endpoints
that once carried it are the same class that February withdrew and that March
closed to development-mode apps entirely - so a recovery lookup would spend
requests from a five-listener quota to be refused.

**Nothing in this repository could see any of it.** `DemoCatalog` fabricated a
popularity - `Int(generator.next(upperBound: 101))` - so the value was always
present in Demo Mode, which is what every test, every screenshot and the whole
harness runs against. `DemoDetailTests` asserted "Every demo track carries a
popularity" and passed, while the shipping path returned `nil` every time. That
is the second time in two days the demo catalogue has manufactured something the
real API stopped sending; the first was decoded cover artwork
([ADR-0025](0025-fetched-covers-are-held.md)).

## Decision

**Popularity is gone: the Attribute, the model field, the fabricated demo value,
and every test and document that named it.**

An arrangement that cannot rank anything is worse than an absent one. It occupies
a chip in the picker, a row in the FAQ with an explanation of a score nobody will
see, and a reading in the detail sheet that is always "Unavailable" - and the
listener's reasonable conclusion is that Sorty is broken, not that Spotify
withdrew a field.

`Playable.popularity` goes with it rather than staying as a decoded field nobody
reads. A property kept "in case it comes back" is a property that quietly starts
lying the day the API changes shape again.

## Consequences

**Twelve attributes, fourteen bases, twenty-six orderings.** The counts are
asserted in `ArrangementTests` rather than derived, and those assertions are the
reason this removal could not be done quietly - four of them failed the moment
the case went, which is exactly their job.

**Everything downstream followed for free**, because it is all derived from
`Attribute.allCases`: the picker, the chip row, the FAQ list and the track detail
sheet. Nothing had a hand-written list of attributes to forget to edit.

**No migration is needed.** An `Arrangement` is never persisted - only the debug
harness parses one from a string - so there is no stored `"pop"` anywhere to
fail to decode.

**Two tests were re-pointed rather than deleted**, because the guarantees they
held are not about popularity. "A track with no measurement has none, rather than
zero" was written when popularity coerced a missing value to zero and drew a
podcast episode a position bar; it now asserts the same rule on `.bpm`. The
audio-features footer test still needs an Attribute below the fold that can go
missing, and release date is one.

**The standing lesson is about the fixture, not the field.** `-demo` proves the
demo path works. Any attribute whose value the demo catalogue *invents* is an
attribute this repo cannot testify about, and the two the catalogue invented -
popularity here, decoded covers in ADR-0025 - were both broken in the shipping
build for an unknown length of time. Worth asking of any new fixture value: does
the real API still send this, and what would tell me if it stopped?
