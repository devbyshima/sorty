# 6. The accent is indigo, not green

Date: 2026-08-06

## Status

Accepted.

## Context

The accent Sortify shipped with was `#1DB966`. Spotify's brand green is
`#1DB954`. Those share the *exact* red and green channel values and differ by
eighteen points of blue — which is not an independent choice that happened to
land nearby.

The consequence is not legal, it is attributional. An app that reads as
first-party makes every rough edge Spotify's fault: a missing BPM becomes
Spotify losing your data rather than a third-party audio-feature source having
no match for a 2025 release.

The spec left the replacement hue deliberately unresolved: "the accent hue has
to be judged against real artwork at real size". Ticket 10 restates it: "A
colour cannot be chosen in the abstract."

## Method

A `-accent RRGGBB` launch argument (DEBUG only) overrides the identity colour
for one launch, so candidates could be shot from a single build against the demo
catalogue's real cover artwork, at real size, beside the position bars, in both
appearances.

Contrast was then computed rather than eyeballed, against the four surfaces the
accent actually lands on: the grouped background and the card in each
appearance.

## Candidates

| candidate | on light bg | on light card | on dark bg | on dark card |
| --------- | ----------: | ------------: | ---------: | -----------: |
| `1DB966` (the old green) | 2.30 | 2.57 | 8.18 | 6.63 |
| `5B4BE0` indigo | **5.33** | **5.95** | 3.53 | 2.86 |
| `2563EB` cobalt | 4.63 | 5.17 | 4.06 | 3.29 |
| `E8543F` coral | 3.26 | 3.64 | 5.77 | 4.68 |

Rejections, and why:

- **Coral** collided with the artwork — half the demo covers are in the red and
  orange family — and worse, red is iOS's destructive colour. It would have sat
  beside an Overwrite action wearing the same red the Overwrite action wears.
- **Cobalt** is close enough to the system's default tint that a tinted app and
  an untinted one look the same. An identity that reads as "nobody chose one" is
  not an identity.
- **The old green** fails badly in light: 2.30:1 on the grouped background is
  below AA for any text, which is what it was being used for.

## Decision

**Light `#5B4BE0`, dark `#8B7BFF`.**

No single indigo serves both. The light value clears AA everywhere it lands
(5.33 and 5.95) but drops to 2.86 on the dark card; lifting it for dark costs
the light case. Hence two values in the colour set — which is what a colour set
is for, and what the old accent was not using properly.

**The foreground on the accent adapts too.** The applied chip draws label on
accent:

| | white on it | near-black on it |
| --- | ---: | ---: |
| light `5B4BE0` | **5.95** | 3.53 |
| dark `8B7BFF` | 3.29 | **6.37** |

There is no constant that clears 4.5:1 against both — arithmetically there
cannot be, since one needs the accent dark and the other needs it light. So
`SortifyTheme.onAccent` is a token resolving to `Color(.systemBackground)`:
white in light, near-black in dark. Writing `.white` at the call site, as the
chip used to, is the failure this prevents.

**Spotify green survives in exactly two places**, and is a constant rather than
an asset colour so it cannot drift with our identity:

1. The connect affordance on the landing screen.
2. `SpotifyAttribution`, which their guidelines require.

## The branding policy, checked 2026-08-06

Their developer design guidelines were read rather than assumed. Three things
came out of it, only one of which the ticket anticipated:

1. **Green is not restricted.** Third parties may use it. The change is ours to
   make on identity grounds, which the channel arithmetic settles regardless.
2. **Attribution is mandatory, and we were not meeting it.** *"If you use any
   Spotify metadata (including artist, album and track names, album artwork, and
   audio playback) it must always be accompanied by the Spotify brand"*, and it
   *"must always link back to the Spotify Service."* Every list screen shows
   exactly that metadata. `SpotifyAttribution` now sits at the foot of both.
3. **Naming is constrained**, which nobody had checked: *"The app name should
   not include 'Spotify' or be similar to 'Spotify' in sound or spelling."*
   "Sortify" is one letter from "Spotify". This ADR does not decide that — it
   records that the guideline exists and that the name sits close to it.

## Consequences

**One outstanding item.** The guidelines ask for the **logo** (icon + wordmark),
not a wordmark set in type. `SpotifyAttribution` currently renders an SF Symbol
and text. The official asset has to come from Spotify's own brand resources —
it is a trademark file, and redrawing it by hand would be worse than not having
it. The component is shaped to take it.

**Naming is a live question, not a settled one.** See point 3 above. It is
outside this ADR's scope and outside the redesign's, but it is now written down.

**`-accent` stays in the build.** DEBUG only. The next time the identity is
questioned, the comparison should be made the same way rather than in a colour
picker.
