# 17. Collaboration is a fact, not a feature

Date: 2026-08-10

## Status

Accepted. Amends [ADR-0008](0008-a-playlist-you-do-not-own-never-opens.md),
whose consequences record a *Collaborative* mark that no longer exists.

## Context

Sorty carried four collaborative surfaces: a chip beside the three that
partition the library by owner, a badge on the row, a Settings section reporting
whether the stored token granted `playlist-read-collaborative` and how many
playlists came back collaborative, and a notice above the library offering a
reconnect to anyone whose token predated the scope.

They were built together and for a good reason. A missing scope makes shared
playlists *absent* rather than broken, which looks exactly like not having any,
and the three ways that can happen - a token granted before Sorty asked for the
permission, a reconnect that silently didn't take, and playlists that are shared
but not actually collaborative - are indistinguishable from the library. Those
rows told them apart.

What has changed is who needs them told apart. The scope has been requested since
it was added; anyone connecting today has it, and the population that predates it
has had a year of prompts. What remains is four pieces of interface explaining a
diagnostic to people who no longer have the fault, on a chip row that partitions
the library by owner and had one member that didn't partition anything.

## Decision

**The chip, the badge, the Settings section and the reconnect notice go.**

Collaboration is not a category. It is an axis crossing all of them: a shared
playlist you own is still yours and a shared playlist Sam owns is still someone
else's, so both stay reachable under chips that already exist. `LibraryViewTests`
asserts exactly that, and it is the assertion that makes the removal safe rather
than merely tidy.

The badge answered a real question - "can other people change this under me?" -
that nothing in Sorty acts on. The two marks that remain each predict a control
the *next* screen will or will not have, which is what a mark on a row is for.

**The scope stays, and this is the whole reason the decision needed recording.**
Dropping `playlist-read-collaborative` would not remove a label. Spotify omits a
playlist you collaborate on from `/me/playlists` entirely without it - not
misclassified, never delivered - and since the February 2026 migration a playlist
you collaborate on is one of only two kinds Spotify will open at all (ADR-0008).
Dropping the scope would remove the playlists.

Because a scope nothing reads looks exactly like a leftover, the test that pins
it is named for the objection: *the collaborative scope is requested even though
nothing is labelled collaborative*.

**`Playlist.collaborative` stays, and so does `contentsAreReadable`'s branch on
it.** This is not sentiment about a field. Delete that line and a playlist Sam
owns and you collaborate on has `category == .other`, trips the pre-check in
`TrackListModel`, and becomes permanently unopenable without a single request -
a functional regression wearing the clothes of a cleanup.

**`SpotifyTokens.grantedScopes` stays; only the `grants(_:)` helper goes.** It is
carried forward across refresh, and it cannot be recovered for a token already in
the Keychain, so deleting the field would mean the next refresh quietly saved a
token that had forgotten its own grant.

## Consequences

**Sorty stops labelling collaboration and keeps naming it as an action in
Spotify.** `EmptyState.contentsWithheld` still says "ask Sam to make it
collaborative", because that is still the way out. The asymmetry is deliberate:
the badge described a state Sorty had no use for; the sentence names a thing the
listener can go and do.

**A shared playlist now looks like any other playlist filed by its owner.** Yours
carries no mark. Sam's carries *Read-only*, which is the true and more useful
answer - it opens, and Sorty will not overwrite it.

**The one diagnostic that is genuinely gone is the reconnect nudge**, and with it
the only in-app way to discover that a very old token is missing a permission.
The remedy has not changed and has never needed the app's help: sign out, connect
again. The FAQ still names the rule.

**Signing out moved to Settings**, which is a consequence of Settings becoming a
page rather than of this decision, but lands with it: the library's overflow menu
now holds only things that change what you are looking at.
