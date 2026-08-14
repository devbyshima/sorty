# Changelog

All notable changes to Sorty are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
Sorty adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**What a version means for an app with no server.** A MAJOR bump is a break in
what a listener's stored state or connected Spotify app can carry across — a
scope change that forces a reconnect, a stored preference that cannot be
migrated. A MINOR bump adds an arrangement, a screen, or an ability. A PATCH
fixes behaviour without adding any. The API Sorty consumes is Spotify's and
changes without warning; a change *there* that costs Sorty a feature is recorded
under `Removed`, at whatever bump the loss deserves.

Pre-releases are tagged `vX.Y.Z-beta.N` and are not listed separately here — a
beta accumulates into the section for the version it is stabilising, which is
published when that version is tagged.

## [Unreleased]

Work on `main`, not yet cut to a release branch. Add to this section as you
merge; `RELEASING.md` explains when it gets renamed to a version.

## [0.2.0] - 2026-08-14

### Added

- The waiting placeholder shimmers, driven off a single clock for every cover
  and text bar in the app ([ADR-0020](docs/adr/0020-the-placeholder-shimmers.md)).
- A playlist opens by growing out of the tile you touched, via
  `.navigationTransition(.zoom(sourceID:in:))`
  ([ADR-0021](docs/adr/0021-a-playlist-opens-by-growing.md),
  [ADR-0024](docs/adr/0024-the-zoom-grows-from-the-cover.md)).
- Fetched cover artwork is held rather than refetched, in a new
  `CoverImageCache` ([ADR-0025](docs/adr/0025-fetched-covers-are-held.md)).
- A reduce-motion screenshot joins the harness set.

### Changed

- Settings has four type roles, and its cards have edges
  ([ADR-0022](docs/adr/0022-settings-has-four-type-roles-and-its-cards-have-edges.md)).
- The progressive blur behind each top bar has no edge to find
  ([ADR-0023](docs/adr/0023-the-blur-has-no-edge-to-find.md)).

### Removed

- **Popularity.** Spotify removed `track.popularity` from the API in February
  2026 and it has no second source, so arranging by it ranked nothing for every
  listener outside Demo Mode. The attribute set drops from thirteen to twelve
  ([ADR-0026](docs/adr/0026-popularity-is-removed.md)).

## [0.1.0] - 2026-08-10

The app as first published: an iOS port of
[Sort Your Music](https://github.com/plamere/SortYourMusic), rebuilt around
arrangements. Never submitted to the App Store — Xcode 27 builds are
TestFlight-only until Apple opens submissions.

### Added

- **Arrangements replace the column table.** A named way of ordering a playlist
  is the first-class control; attribute-derived and computed orderings are peers
  ([ADR-0001](docs/adr/0001-arrangements-replace-the-column-table.md)).
- Twelve attributes and two computed arrangements — Artist separation and
  Shuffle — for 26 distinct orderings, on a chip row of five pinned bases plus
  `More`.
- Track detail: every attribute a track has, on a sheet
  ([ADR-0010](docs/adr/0010-the-track-row-shows-no-position-number.md)).
- Tracks an arrangement cannot place are gathered into labelled groups that say
  why, rather than sinking silently.
- **Save split by what each path may write.** Overwrite always writes the whole
  playlist, never the filtered subset
  ([ADR-0002](docs/adr/0002-overwrite-always-writes-the-whole-playlist.md));
  only save-as-new may write a subset, and it says so.
- **Save a Copy**, armed from load on any playlist you do not own
  ([ADR-0017](docs/adr/0017-collaboration-is-a-fact-not-a-feature.md)).
- Library with All / Mine / Spotify / Others chips and counts, name search,
  three layouts and three orders, all persisted
  ([ADR-0009](docs/adr/0009-the-library-opens-two-up.md)).
- Connecting is the front door: a guided four-step flow for registering your own
  Spotify Client ID, built as a reel
  ([ADR-0007](docs/adr/0007-connecting-is-the-front-door.md),
  [ADR-0016](docs/adr/0016-the-way-in-is-a-reel.md)).
- Settings as a page with three sub-pages, and a testable copy layer in
  `SortyKit` for every word the app says.
- Light and dark, both authored, followed from the device unless overridden.
- Its own colour: indigo, not Spotify green
  ([ADR-0006](docs/adr/0006-the-accent-is-indigo-not-green.md)).
- Skeletons shaped like what is coming, and a splash that waits for one row
  ([ADR-0019](docs/adr/0019-a-skeleton-is-the-shape-of-what-is-coming.md)).
- A headless screenshot harness reaching every screen from a cold launch through
  DEBUG-only launch arguments, never driving the simulator GUI.

### Changed

- Renamed from Sortify to Sorty — the old name was one letter from Spotify
  ([ADR-0014](docs/adr/0014-the-app-is-called-sorty.md)).
- Release dates are read from the track's own album rather than batch
  `GET /albums`, which Spotify withdrew.
- Spotify's attribution mark is Spotify's own file, drawn to their rules
  ([ADR-0013](docs/adr/0013-the-attribution-mark-is-spotifys-own-file.md)).

### Removed

- **Demo Mode leaves the shipped app.** It survives under `#if DEBUG` as the
  fixture layer for the tests and the screenshot harness, entered only by the
  `-demo` launch argument
  ([ADR-0007](docs/adr/0007-connecting-is-the-front-door.md), superseding
  [ADR-0003](docs/adr/0003-demo-mode-is-the-front-door.md)).

### Known limits

None of these are in Sorty's control, and all of them are things people hit.

- Audio features 403 for any newly registered app; Sorty defaults to
  [ReccoBeats](https://reccobeats.com) instead, thin for 2025-onward releases.
- Spotify's own playlists — Discover Weekly, Release Radar, the Daily Mixes, the
  editorial lists — cannot be opened by any app at this quota tier. Sorty marks
  them *Can't open* and says why
  ([ADR-0018](docs/adr/0018-spotifys-own-playlists-are-one-thing-sorty-cannot-open.md)).
- A playlist you neither own nor collaborate on never opens; Spotify sends its
  contents to nobody else
  ([ADR-0008](docs/adr/0008-a-playlist-you-do-not-own-never-opens.md)).
- A development-mode Spotify app admits five listeners and requires its owner to
  hold Premium, which is why Sorty asks for your own Client ID.

[Unreleased]: https://github.com/devbyshima/sorty/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/devbyshima/sorty/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/devbyshima/sorty/releases/tag/v0.1.0
