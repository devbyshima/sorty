# Sortify

A native iOS port of [Sort Your Music](https://github.com/plamere/SortYourMusic) — sort a Spotify
playlist by tempo, energy, danceability, loudness, valence and more, then save the new order back.

SwiftUI, iOS 27, no third-party packages.

## Status

Feature-complete against the reference app and verified on the iOS 27 simulator.
69 tests pass; the build is warning-free.

| Screen | |
|---|---|
| Landing | `screenshots/01-landing.png` |
| Playlists | `screenshots/02-playlists.png` |
| Track table | `screenshots/03-tracks-order.png`, `04-tracks-bpm.png`, `05-tracks-asep.png` |
| Settings / FAQ | `screenshots/06-settings.png`, `07-faq.png` |

## Read this first: Spotify closed the endpoint this app was built on

Sort Your Music sorts by Spotify's **audio features** (tempo, energy, danceability, loudness,
valence, acousticness). On **27 November 2024** Spotify restricted `GET /v1/audio-features` to apps
that already held extended quota, and has shipped **no replacement** since. A Spotify app registered
today gets `403` on every call, and extended quota now requires a registered company with 250k+
monthly active users — a hobby app can never qualify.

So a literal port would ship with six of its fifteen columns permanently blank.

Sortify treats the feature source as swappable (`AudioFeatureProviding`) and defaults to
**[ReccoBeats](https://reccobeats.com)**, which is free, needs no API key, is keyed by Spotify track
ID, and returns values on Spotify's exact scale. Coverage is strong for catalogue released up to 2024
and thin for 2025-onward releases; anything it misses shows a dash and sorts last, and the app says
so rather than looking broken.

The other three options are in Settings: Spotify's own endpoint (for a grandfathered Client ID),
and None.

Two more Spotify constraints worth knowing before you try to connect:

- **A development-mode app admits at most five listeners**, and its owner needs Spotify Premium.
  That's why Sortify asks for *your* Client ID rather than shipping one — a shared ID would be full
  after five people.
- **February 2026 renamed and removed endpoints** for newly registered Client IDs:
  `/playlists/{id}/tracks` → `/playlists/{id}/items`, `POST /users/{id}/playlists` →
  `POST /me/playlists`, batch `GET /albums` withdrawn, and `track.popularity` removed. The client
  speaks the new spellings and falls back to the old ones on 404, so it works with either vintage of
  Client ID.

## Demo Mode

Because of all that, the app opens in **Demo Mode**: a bundled, invented catalogue of seven playlists
with full acoustic data. Every column populates and every sort works with no account and no network.
It's read-only — there's nothing to save back.

The catalogue is fictional (invented artists and titles) so no made-up measurement is ever attached
to a real recording. It's generated from a fixed seed, so screenshots and tests are reproducible.

## Setting up a real Spotify connection

1. Create an app at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard).
2. Register the redirect URI **exactly** as it appears in Sortify's Settings (default
   `sortify://callback`).
3. Add your own Spotify account under **Users Management**.
4. Paste the Client ID into Settings and switch Source to Spotify.

Scopes requested: `playlist-read-private`, `playlist-modify-private`, `playlist-modify-public` —
the same three the reference app uses, and nothing more.

**On the redirect URI:** Spotify's docs permit custom schemes, but dashboards have been rejecting
them as "Insecure redirect URI" for Client IDs created since April 2025. If that happens, point the
redirect at an https URL you control and put the same value in Settings — the app switches to an
https callback automatically when you do.

Auth is Authorization Code + PKCE in `ASWebAuthenticationSession`. No client secret ships in the
binary. Tokens live in the Keychain as `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, so they
survive a relaunch but never ride a backup onto another device.

## Feature parity with the reference

All fifteen columns, with the reference's exact semantics:

`#` · `Title` · `Artist` · `Release` · `Added` · `BPM` · `Energy` · `Dance` · `Loud` · `Valence` ·
`Length` · `Acoustic` · `Pop.` · `A.Sep` · `Rnd`

- 0–1 features are shown 0–100; tempo and loudness round to whole units.
- Tapping the active column flips direction; tapping a new one starts ascending.
- `A.Sep` and `Rnd` have no direction. Re-tapping `Rnd` reshuffles.
- Missing values always sort **last**, in both directions.
- Ties keep original playlist order, so sorting is stable and repeatable.
- BPM range filter with the **doubled-BPM** option; rows with no BPM are never hidden.
- Save is disabled until the arrangement actually differs from what's on Spotify.
- Save as new playlist (`"{name} ordered by increasing BPM"`, description preserved) or overwrite —
  overwrite only offered for playlists you own and that aren't algorithmic.
- Playlist categories (Mine / Personalized / Spotify / Others / Collaborative) with counts and
  name search.
- Podcast episodes render greyed, carry no acoustic values, and are preserved on save.

### Deliberate differences

| | Reference | Sortify | Why |
|---|---|---|---|
| Audio features | Spotify `/v1/audio-features` | ReccoBeats by default, pluggable | The Spotify endpoint 403s for any new app |
| Track preview | Plays a 30s clip on row tap | Swipe a row to open in Spotify | Spotify stopped serving `preview_url` to new apps at the same time |
| Artist separation with episodes | Crashes — it skips artist-less entries, then dereferences `artists[0].name` on one | Artist-less entries share a bucket and are distributed | A crash isn't worth porting faithfully |
| Layout | 15-column HTML table | Same 15 columns, scrolled horizontally; the sorted column auto-centres | 15 columns don't fit a phone; hiding them would lose the point of the app |

## Architecture

```
SortifyKit/          pure logic — compiled into the app AND the test target
  Models/            Spotify payloads; decode both pre- and post-Feb-2026 shapes
  Sorting/           SortColumn, TrackRow, PlaylistSorter, ArtistSeparation
  Spotify/           MusicService protocol, live client, demo catalogue
  Features/          AudioFeatureProviding: ReccoBeats, Spotify, None, Demo
  Auth/              PKCE, Keychain token store, authenticator, configuration
  ViewModels/        SessionModel, TrackTableModel (@Observable, @MainActor)
Sortify/             SwiftUI app target
Tests/               Swift Testing — 69 tests, hostless
```

The test target compiles `SortifyKit` directly and runs without an app process, so the sorting engine,
decoding, PKCE and save behaviour are all testable with no simulator UI and no network.

## iOS 27

Deployment target 27.0, built with Xcode 27 / Swift 6.4. APIs genuinely new in 27 that this app uses:

- `PickerStyle.tabs` for the playlist category filter
- `swipeActions` + `swipeActionsContainer()` — swipe on a `LazyVStack` row, not just in a `List`
- `ToolbarContent.visibilityPriority(_:)` so Save outranks Filter when the bar gets tight
- Liquid Glass button styles (`.glass`, `.glassProminent`) — iOS 26 API, unconditional in 27

**Note on shipping:** App Store *production* uploads still require Xcode 26 and an iOS 26 SDK.
Xcode 27 builds are TestFlight-only until Apple opens submissions. Nothing here needs iOS 27
specifically — dropping the deployment target to 26 costs only the four APIs above.

## Development

```sh
xcodegen generate                    # regenerate Sortify.xcodeproj after changing project.yml
xcodebuild -project Sortify.xcodeproj -scheme Sortify \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' test
./scripts/screenshots.sh             # headless screenshots of every screen
```

`scripts/screenshots.sh` never drives the simulator GUI — each screen is reached from a cold launch
via DEBUG-only launch arguments (`-screen`, `-playlist`, `-sort`, `-direction`) and captured with
`simctl io screenshot`.

## Credits

Port of [Sort Your Music](https://github.com/plamere/SortYourMusic) by Paul Lamere.
Not affiliated with or endorsed by Spotify.
