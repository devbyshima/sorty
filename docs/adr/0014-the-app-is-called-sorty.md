# 14. The app is called Sorty

Date: 2026-08-09

## Status

Accepted. Closes the naming question ADR-0006 opened and left live.

## Context

ADR-0006 recorded a guideline nobody had checked, and deliberately did not decide
it:

> The app name should not include 'Spotify' or be similar to 'Spotify' in sound
> or spelling.
>
> - Design & Branding Guidelines, "Logo and naming restrictions"

The research in `.scratch/ui-redesign-2/research/spotify-resemblance-policy.md`
found the Policy states it a second time, with a detail the guidelines page does
not carry:

> You must also follow the Branding Guidelines when naming your SDA. For example,
> the name should not begin with "Spot" or be confusing in sound or spelling to
> Spotify.
>
> - Developer Policy § VI.2

And it found the sharper edge, which is not Spotify's:

> **4.1 Copycats (a)** […] Don't simply copy the latest popular app on the App
> Store, or make some minor changes to another app's name **or** UI and pass it
> off as your own.
>
> - App Store Review Guidelines

"Sortify" did not begin with "Spot". It was one substituted letter from
"Spotify" - same length, same rhythm, same `-ify` ending - which is difficult to
argue against a test whose own words are "similar in sound or spelling". And
4.1(a) is assessed by a human at submission, on name *or* UI, which means the
name did not have to fail on its own to matter.

## Decision

**The app is called Sorty.**

It contains no part of "Spotify". It does not begin with "Spot" - it begins with
"Sort", which is what the app does. It is two letters shorter, and it drops the
`-ify` suffix, which was carrying most of the resemblance. Against the two
written tests it is no longer a close call.

## Why now, and not later

The timing is the whole argument, and it is arithmetic rather than judgement.

Nothing has shipped. No tag, no App Store listing, no TestFlight build, no
installed base - so **no listener has `sortify://callback` registered in their
own Spotify developer application**, which is the one part of this app's name
that lives outside this repository. Under the connect flow every user pastes a
redirect URI into Spotify's dashboard by hand, so after a single release a scheme
change would have been a migration for every user rather than a sweep.

The cost today was 164 occurrences across 72 files, a bundle identifier, a URL
scheme, three renamed files and two renamed directories. After the first
submission it would additionally cost a review cycle; after any traction, the
brand.

## What it cost, and one thing it did not

**The icon and the in-app mark are untouched.** `SortyMark` and
`scripts/make_icon.swift` draw four pills of descending length - a set of things
put in order - from shared fractions. There is no letterform anywhere in the
identity, so the rename reached no artwork at all. That was luck rather than
foresight, and it is worth writing down as an argument for keeping it that way.

**`.scratch/` was deliberately not swept.** It is a closed record of finished
work, dated and superseded, and nothing points into it as a live reference. It
says "Sortify" throughout because that is what the app was called when it was
written. The same is true of every commit message before this one.

**`docs/adr/` was swept, with one exception.** These are living reference - the
first instruction to anyone touching this codebase is to read them - and an ADR
pointing at `SortifyTheme` would be a pointer that no longer resolves. The
exception is ADR-0006's point 3, which asserts that the name is one letter from
"Spotify". That is a claim *about a name* rather than about the app, and
rewriting it would have turned a true sentence into a false one. It keeps the old
spelling and says why.

That exception is the general hazard of this kind of sweep, and it was caught by
grepping the swept text for claims about the name rather than by reading the
diff.

## Consequences

**The redirect URI is now `sorty://callback`.** It must be registered verbatim in
each listener's own Spotify dashboard, and it is the value the connect flow
displays for copying. Any Client ID configured against the old scheme will fail
authorization until its dashboard entry is updated - which today means the
founder's own, and nobody else's.

**The bundle identifier is `com.fulltimestudio.sorty`.** A simulator or device
carrying the old build will keep it as a separate app; it is not an upgrade.

**Apple 4.1(a) is not fully answered by this.** The clause reads on name *or* UI,
and this decision addresses one of the two. The UI resemblance question - what
the second redesign chose to match - is recorded in the research and is not
reopened here. What has changed is that the two no longer compound.
