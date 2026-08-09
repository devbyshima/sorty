# Sorty

A native iOS app that reorders a Spotify playlist by the musical character of its tracks - tempo,
energy, mood - and saves the result back. Originally a port of
[Sort Your Music](https://github.com/plamere/SortYourMusic).

SwiftUI, iOS 27, no third-party packages.

## Status

298 tests in 38 suites (379 cases once the parameterized ones expand), all passing.

A simulator build emits one benign `AppIntents.framework` metadata warning. A device or Release build
additionally warns that *all interface orientations must be supported unless the app requires full
screen* - the target ships for iPhone **and** iPad (`project.yml:47`) without declaring orientations
or `UIRequiresFullScreen`, while [ADR-0001](docs/adr/0001-arrangements-replace-the-column-table.md)
rules iPad out. Config and decision disagree; the warning is the symptom.

| Screen | |
|---|---|
| The way in | `screenshots/00-signed-out.png` |
| Library | `01-playlists.png`, `14-playlists-two-up.png` |
| Playlist | `02-tracks-order.png`, `03-tracks-bpm.png`, `04-tracks-asep.png`, `05-tracks-shuffle.png` |
| Off-piste and unrankable | `06-tracks-offpiste.png`, `07-tracks-unrankable.png` |
| Track detail | `08-track-detail.png`, `09-track-detail-missing.png` |
| Arrangement picker | `10-arrangements.png` |
| Connect flow | `11-connect-why.png`, `12-connect-app.png`, `13-connect-id.png` |
| Settings / FAQ | `15-settings.png`, `16-faq.png` |
| Dynamic Type | `17`–`21` (largest, then one step into the accessibility sizes) |
| Dark Appearance | `22`–`25` |
| Progressive blur | `26`–`29` (the only shots where content passes *under* a header) |

## Read this first: Spotify closed the endpoint this app was built on

Sort Your Music sorts by Spotify's **audio features** (tempo, energy, danceability, loudness,
valence, acousticness). On **27 November 2024** Spotify restricted `GET /v1/audio-features` to apps
that already held extended quota, and has shipped **no replacement** since. A Spotify app registered
today gets `403` on every call, and extended quota now requires a registered company with 250k+
monthly active users - a hobby app can never qualify.

Sorty treats the feature source as swappable (`AudioFeatureProviding`) and defaults to
**[ReccoBeats](https://reccobeats.com)**, which is free, needs no API key, is keyed by Spotify track
ID, and returns values on Spotify's exact scale. Coverage is strong for catalogue released up to 2024
and thin for 2025-onward releases; anything it misses is shown as unavailable and gathered into a
labelled group rather than silently sinking to the bottom.

The other two options are in Settings: Spotify's own endpoint (for a grandfathered Client ID), and
None.

Two more Spotify constraints worth knowing before you try to connect:

- **A development-mode app admits at most five listeners**, and its owner needs Spotify Premium.
  That's why Sorty asks for *your* Client ID rather than shipping one - a shared ID would be full
  after five people.
- **February 2026 renamed and removed endpoints** for newly registered Client IDs:
  `/playlists/{id}/tracks` → `/playlists/{id}/items`, `POST /users/{id}/playlists` →
  `POST /me/playlists`, batch `GET /albums` withdrawn, and `track.popularity` removed. The client
  speaks the new spellings and falls back to the old ones on 404, so it works with either vintage of
  Client ID.

## Setting up a Spotify connection

Connecting is how the app starts - see [ADR-0007](docs/adr/0007-connecting-is-the-front-door.md).

1. Create an app at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard).
2. Register the redirect URI **exactly** as Sorty shows it (default `sorty://callback`).
3. Add your own Spotify account under **Users Management**.
4. Paste the Client ID into the connect flow, which walks these four steps.

Scopes requested: `playlist-read-private`, `playlist-read-collaborative`, `playlist-modify-private`,
`playlist-modify-public` - enough to read your playlists and write an arrangement back, and nothing
more.

`playlist-read-collaborative` is what lets Sorty see playlists shared with you. Without it Spotify
leaves them out of its response altogether, so they cannot be arranged and the Collaborative filter is
always empty. If you connected before Sorty asked for it, the library offers you a reconnect, and
Settings shows whether the current token actually carries the permission.

**On the redirect URI:** Spotify's docs permit custom schemes, but dashboards have been rejecting
them as "Insecure redirect URI" for Client IDs created since April 2025. If that happens, point the
redirect at an https URL you control and put the same value in Settings - the app switches to an
https callback automatically when you do.

Auth is Authorization Code + PKCE in `ASWebAuthenticationSession`. No client secret ships in the
binary. Tokens live in the Keychain as `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so they
survive a relaunch but never ride a backup onto another device.

## The sample catalogue

There is a bundled, invented catalogue of seven playlists with full acoustic data, and **it does not
ship**. `DemoCatalog`, `DemoMusicService` and `DemoArtwork` are wrapped in `#if DEBUG`, so the
compiler never sees them in Release; the tests and `scripts/screenshots.sh` both build Debug and both
use them. Reaching it needs the `-demo` launch argument - nothing a listener can do gets there.

`DEBUG` is defined by Xcode's own default for the Debug configuration and is empty in Release; the
project does not set `SWIFT_ACTIVE_COMPILATION_CONDITIONS` itself. A Release build compiling is the
proof that nothing outside those fences references the catalogue.

The catalogue is fictional (invented artists and titles) so no made-up measurement is ever attached
to a real recording. It's generated from a fixed seed, so screenshots and tests are reproducible.

## What the app does

The UI is built on **arrangements**, not columns - see
[ADR-0001](docs/adr/0001-arrangements-replace-the-column-table.md). An *arrangement* is a named way of
ordering a playlist; an *attribute* is a property a track has. Attribute-derived orderings and
computed ones are peers.

**Thirteen attributes**: Original order, Title, Artist, Release date, Date added, BPM, Energy,
Danceability, Loudness, Valence, Length, Acousticness, Popularity. **Two computed arrangements**:
Artist separation and Shuffle. 28 distinct orderings in total.

- A **chip row** carries five pinned bases that never move - Original order, BPM, Energy, Artist
  separation, Shuffle - plus a trailing chip when the applied arrangement is off-piste, plus `More`,
  which opens a picker listing every basis with its explanation.
- Tapping the active chip flips direction; tapping another starts ascending. Direction shows as an
  arrow on the active chip only. Artist separation and Shuffle have no direction, and Shuffle's
  re-roll is a **separate button** so one gesture never means two things.
- A row shows artwork, title, artist, the active arrangement's value, and a bar placing that value in
  the playlist's range. There is no position number: VoiceOver still announces rank, but the column
  went so artwork could sit at the same margin as everything else.
- 0–1 features render 0–100; tempo and loudness round to whole units. Ties keep original playlist
  order, so sorting is stable and repeatable.
- Tracks an arrangement cannot place are gathered under **labelled groups** saying why - a podcast
  episode, a track nobody measured, a value Spotify didn't supply - rather than sinking silently.
- **BPM range filter** with a doubled-BPM option; tracks with no BPM are never hidden by it.
- **Save is two actions with two gates.** Save-as-new arms on an arrangement *or* filter change;
  overwrite arms on the arrangement alone. Overwrite is offered only for playlists you own that
  aren't algorithmic. Disabled actions are dimmed rather than absent.
- **Overwrite always writes the whole playlist**, never the filtered subset
  ([ADR-0002](docs/adr/0002-overwrite-always-writes-the-whole-playlist.md)). Only save-as-new may
  write a subset, and it says so. The new playlist is named `"{original} ordered by {arrangement}"`;
  its description is rewritten rather than preserved.
- **Track detail sheet**: every attribute for one track, split into what came from an analysis
  provider and what came from Spotify, with "Unavailable" where a measurement is missing.
- **Library**: All / Mine / Spotify / Others / Collaborative filters with counts and name search.
  Personalized playlists are reachable under Spotify rather than getting a chip of their own. Three
  layouts - Large grid (2-up, the default), Small grid (3-up), List - and three orders, both
  persisted.
- **Appearance** is light or dark, both authored, followed from the device unless overridden.
- Podcast episodes render greyed, carry no acoustic values, are grouped as unrankable, and are
  preserved on save.

### Deliberate differences from the reference

| | Reference | Sorty | Why |
|---|---|---|---|
| Audio features | Spotify `/v1/audio-features` | ReccoBeats by default, pluggable | The Spotify endpoint 403s for any new app |
| Layout | 15-column HTML table | One attribute at a time on a list, with arrangements as the primary control | 15 fixed-width columns sum to ~3.4 screens on a phone; the sorted column auto-centring pushed track identity off the left edge (ADR-0001) |
| Comparing attributes | Read across a row | Open the track detail sheet | The accepted cost of ADR-0001 |
| Track preview | Plays a 30s clip on row tap | Swipe a row to open in Spotify | Spotify stopped serving `preview_url` to new apps at the same time |
| Artist separation with episodes | Crashes - skips artist-less entries, then dereferences `artists[0].name` on one | Artist-less entries share a bucket and are distributed | A crash isn't worth porting faithfully |

## Decisions

Architecture decisions live in [`docs/adr/`](docs/adr/), vocabulary in [`CONTEXT.md`](CONTEXT.md).

| ADR | |
|---|---|
| [0001](docs/adr/0001-arrangements-replace-the-column-table.md) | Arrangements replace the column table |
| [0002](docs/adr/0002-overwrite-always-writes-the-whole-playlist.md) | Overwrite always writes the whole playlist |
| [0003](docs/adr/0003-demo-mode-is-the-front-door.md) | ~~Demo Mode is the front door~~ — superseded by 0007 |
| [0004](docs/adr/0004-original-order-is-a-name-not-a-case.md) | Original order is a name, not a case |
| [0005](docs/adr/0005-the-reorder-threshold-is-a-thousand-rows.md) | The reorder animation snaps above 1,000 rows — measured, not guessed |
| [0006](docs/adr/0006-the-accent-is-indigo-not-green.md) | The accent is indigo, not Spotify green |
| [0007](docs/adr/0007-connecting-is-the-front-door.md) | Connecting is the front door; Demo Mode leaves the shipped app |

## Architecture

```
SortyKit/          pure logic - compiled into the app AND the test target
  Models/            Spotify payloads, plus the copy layer: EmptyState, PlaylistRowText,
                     LoadFailure, ReconnectNotice, LibraryView (order/layout/preferences)
  Sorting/           Arrangement, Attribute, ArrangementChip, PlaylistSorter, ArtistSeparation,
                     TrackRow, TrackRowText, TrackDetail, UnrankableGroup, SaveAction,
                     AttributeRange, ReorderAnimation
  Spotify/           MusicService protocol, live client, CoverImageLoader
                     (+ DemoCatalog / DemoMusicService / DemoArtwork, DEBUG only)
  Features/          AudioFeatureProviding: ReccoBeats, Spotify, None
  Auth/              PKCE, Keychain token store, authenticator, configuration, ConnectFlow
  ViewModels/        SessionModel, TrackListModel (@Observable, @MainActor)
Sorty/             SwiftUI app target
Tests/               Swift Testing, hostless
```

**User-facing copy is a testable layer.** Anything a screen *says* - empty states, row text, badges,
unrankable-group reasons, save-action titles, the reconnect prompt - is decided in `SortyKit` where
a test can assert on it, not typed into a view. Views render what they are handed.

The test target compiles `SortyKit` directly and runs without an app process, so sorting, decoding,
PKCE and save behaviour are all testable with no simulator UI and no network.

## iOS 26/27 API in use

Deployment target 27.0, Xcode 27, Swift 6.0.

- **Liquid Glass** via `.glassEffect(.regular.interactive(), in:)` on chips, top-bar buttons and the
  Save anchor, inside a `GlassEffectContainer`. `.buttonStyle(.glassProminent)` is used once, in the
  connect flow; `.buttonStyle(.glass)` is deliberately not used - it sizes itself from its label and
  cannot be asked for an exact diameter.
- `.onScrollGeometryChange(for:)` derives whether the chip row has pinned, which decides where the
  blur's fade lives.
- `onGeometryChange(for:action:)` measures headers so a blur is never sized to a guess.
- `ScrollPosition` + `.scrollPosition($)` backs the `-scrolled N` harness hook.
- `.lineLimit(_:reservesSpace:)` reserves the second line of a grid tile's name, which is what makes
  the library grid actually align.
- `.visualEffect { }`, `.swipeActions` on a `LazyVStack` row via `swipeActionsContainer()`,
  `.toolbarBackgroundVisibility`, `.scrollClipDisabled()`, `@ScaledMetric(relativeTo:)`.

**One private API.** The progressive blur behind each screen's top bar drives the `variableBlur`
`CAFilter` through a `UIViewRepresentable` - the same filter UIKit uses for its own navigation-bar
blurs. There is no public equivalent. It degrades to no blur at all if that API ever changes.

**Note on shipping:** App Store *production* uploads still require Xcode 26 and an iOS 26 SDK.
Xcode 27 builds are TestFlight-only until Apple opens submissions.

## Development

```sh
xcodegen generate                    # after changing project.yml; never hand-edit the .xcodeproj
xcodebuild -project Sorty.xcodeproj -scheme Sorty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' test
./scripts/screenshots.sh             # headless screenshots of every screen
SETTLE=6 ./scripts/screenshots.sh    # slower machine
DEVICE="iPhone 17" OS=27.0 ./scripts/screenshots.sh
```

`scripts/screenshots.sh` never drives the simulator GUI. Each screen is reached from a **cold launch**
via DEBUG-only launch arguments and captured with `simctl io screenshot`. It stages into a temp
directory and replaces `screenshots/` wholesale, so a screen that no longer exists cannot leave a
stale PNG behind pretending it does.

The arguments, all compiled out of Release:

| | |
|---|---|
| `-screen <name>` | `playlists`, `tracks`, `faq`, `settings`, `connect`, `signedOut`, `profile` |
| `-demo` | the only way into the sample catalogue |
| `-playlist <id>` | which demo playlist to open |
| `-arrangement <arg>` | `bpm-descending`, `artist-separation`, `shuffle-<seed>`, … — one argument, because a basis plus a direction could name a combination that doesn't exist |
| `-sheet <name>` | `arrangements`, `filter`, `track` |
| `-track N` | which row `-sheet track` opens |
| `-filter LOW-HIGH` | a tempo range |
| `-scrolled N` | arrive N points down, so the blur is photographable at all |
| `-layout <raw>` | `grid2`, `grid`, `list` |
| `-connectStep <step>` | a step of the connect flow |
| `-accent RRGGBB` | override the identity colour for one launch (how ADR-0006 was decided) |
| `-count N` | playlist size for `-screen profile` (how ADR-0005 was measured) |

## Credits

Port of [Sort Your Music](https://github.com/plamere/SortYourMusic) by Paul Lamere.
Not affiliated with or endorsed by Spotify.
