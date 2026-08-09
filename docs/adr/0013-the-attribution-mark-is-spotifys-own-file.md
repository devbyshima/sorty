# 13. The attribution mark is Spotify's own file, in monochrome

Date: 2026-08-09

## Status

Accepted. Closes ADR-0006's outstanding item.

## Context

ADR-0006 left one thing open and wrote it down plainly: the guidelines ask for
the **logo** (icon + wordmark), and `SpotifyAttribution` was drawing an SF Symbol
beside the words "Content from Spotify". The official asset had to come from
Spotify's own brand resources, and redrawing a trademark by hand would be worse
than not having it.

Closing it turned up something the ADR could not have known, because it was true
only after the ADR was written.

**The attribution was not being shown at all.** ADR-0006 records that
`SpotifyAttribution` "now sits at the foot of both" list screens. It did, at
`85edf73`. The library and track-list rebuild in `b15aa47` replaced the
containers both call sites lived in, and both went with them - along with the
comment that said "Required wherever Spotify's metadata is shown, which every row
above is." The component survived, declared and referenced by nothing, for eleven
commits. Every screenshot in the set was taken above the fold, so the whole
verification apparatus could not see it.

That is the more serious half of this ADR. The obligation is the one Spotify
states unconditionally, in both binding documents:

> If you use any Spotify metadata (including artist, album and track names, album
> artwork, and audio playback) it must always be accompanied by the Spotify brand
> […] it must always link back to the Spotify Service.
>
> - Design & Branding Guidelines

> If you display any Spotify Content you must clearly attribute the content as
> being supplied and made available by Spotify, by using the Spotify Marks. […]
> Metadata, cover art and Audio Preview Clips must be accompanied by a link back
> to the applicable album, content or playlist on the Spotify Service.
>
> - Developer Policy § II.4

## Decision

**The mark is Spotify's own file, monochrome, never below 70pt, with its
exclusion zone, and no words beside it.**

Every one of those five is a clause rather than a preference, which is why the
component's doc comment quotes each against the line of code it governs.

**The file.** `2024-spotify-full-logo.zip`, from the download on
<https://developer.spotify.com/documentation/design>. Two of its twenty-seven
files are used - `Full_Logo_Black_RGB.svg` and `Full_Logo_White_RGB.svg` -
unmodified, as the two appearance variants of one `SpotifyLogo` imageset. The
full logo and not the icon: *"In partner integrations, you should always use our
full logo (icon + wordmark)."*

**Monochrome, which retires the green here.** *"The Spotify green logo should
only be used on a black or white background, for any other background you should
use a monochrome logo."* `SortifyTheme.background` is `#F4F4F7` light and
`#0D0D0D` dark. Neither is black and neither is white, so on the guidelines' own
terms the green logo does not belong at the foot of these screens - and the two
official monochrome files are exactly the black-on-light, white-on-dark pair the
next sentence asks for.

**Not `.renderingMode(.template)`**, which would have been the obvious SwiftUI
way to get one asset to serve both appearances, and is forbidden: *"Don't fill
the lines of the logo."* Two files, no tinting.

**70pt floor, and a ceiling of our own.** *"The Spotify logo should never be
smaller than 70px."* `@ScaledMetric` respects a listener who has asked for larger
text, but uncapped it was measured at roughly 350pt at
accessibility-extra-extra-extra-large, which made a footer mark the largest thing
on the library screen. It is capped at 2x. A logo is not text; Spotify already
set its legibility floor.

**The exclusion zone is the padding.** *"The exclusion zone is equal to half the
height of the icon."* Computed from the drawn height rather than typed in, so it
stays correct at every size the cap allows.

**No caption.** The previous version read "Content from Spotify" beside a glyph.
With the real wordmark in place, words saying Spotify again would be the thing
the guidelines name outright: *"Don't use the logo in a sentence or as a letter."*

**The track screen links to its own playlist**, not to the service. § II.4 asks
for "a link back to the applicable album, content or playlist", and that screen
knows which playlist it is showing. It uses the `https://open.spotify.com/...`
form rather than the `spotify:` URI the rest of the screen uses, because a
universal link opens the app where it is installed and the web player where it is
not.

## Consequences

**ADR-0006's "Spotify green survives in exactly two places" is now one.** The
connect affordance on the landing screen keeps it. The attribution mark does not,
by the colourway rule above. `SortifyTheme.spotifyGreen` still has a third caller
that ADR-0006 did not list - the Open on Spotify capsule in `TrackDetailSheet` -
which is a green surface rather than a green logo and is untouched by this.

**Two screenshots exist that look below the fold**, `32-playlists-attribution` and
`33-dark-tracks-attribution`, both scrolled by an offset large enough that
`scrollTo` clamps to the end of any list. They are in the set because of how this
was lost: no shot in a set of thirty-one could see the foot of a screen, so the
loss was invisible to the only verification this project has. **The dark one is
the one that matters** - if the white file ever fails to import, the logo renders
black on `#0D0D0D` and disappears, and nothing but an eye on that image will
catch it.

**What this does not settle.** The naming question ADR-0006 raised is untouched
here and remains open. It is a separate decision, recorded in ADR-0014.
