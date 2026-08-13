# Contributing to Sorty

Sorty is a native iOS app — SwiftUI, Swift 6, iOS 27, **no third-party
packages**. That last one is a standing constraint, not an accident: adding a
dependency is a decision that needs an ADR, not a line in a manifest.

## Setting up

```bash
git clone https://github.com/devbyshima/sorty.git
cd sorty
xcodegen generate
open Sorty.xcodeproj
```

You will also need your own Spotify Client ID to run the app against a real
account — see [the README](README.md#getting-started). Spotify caps a
development-mode app at five authorised listeners, which is why Sorty asks for
yours rather than shipping one.

> [!IMPORTANT]
> **`Sorty.xcodeproj` is generated and gitignored. Never hand-edit it, and never
> commit it.** Project changes go in `project.yml`, followed by
> `xcodegen generate`. CI fails if the project file is ever tracked.

## Branches

| Branch | For | Rule |
|---|---|---|
| `main` | all new feature work | The trunk. Everything starts here. |
| `release/X.Y` | stabilising a version | **Bug fixes only.** Cut from `main`. |
| `hotfix/X.Y.Z-<slug>` | a fix for a released version | Branched from the **oldest** affected `release/X.Y` |
| `feature/<slug>`, `fix/<slug>` | your working branch | Branched from `main`, PR'd back into it |

Three rules that carry all the weight:

1. **New features only ever land on `main`.** A release branch that takes a
   feature is no longer a thing you can reason about, and its whole value was
   that you could.
2. **A production bug is fixed on the oldest release branch that has it**, then
   merged forward into every newer release branch and `main`. Fixing it on
   `main` first strands it there.
3. **Never force-push a shared branch.** `main` and every `release/*` are
   shared. Your own feature branch is yours until someone else pulls it.

Releasing — cutting branches, betas, promotion, hotfixes, propagation — is
[RELEASING.md](RELEASING.md), with the exact commands.

## Pull requests

Every PR targets `main`, or a `release/*` branch if it is a bug fix for that
release. PRs are how CI gets a chance to speak.

- Keep the subject line in the imperative and about the change's *intent*, the
  way the existing history does — "Take the sheen off Spotify's artwork, and
  keep the lean", not "update CoverImage.swift".
- Add tests for anything in `SortyKit`. It exists to be testable.
- Add a `CHANGELOG.md` entry under `## [Unreleased]` if the change is one a
  listener would notice. Refactors and internal work do not need one.
- If the change makes or overturns a decision, write an ADR. See below.

## Tests

```bash
xcodebuild -project Sorty.xcodeproj -scheme Sorty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' test
```

The test target is hostless — it compiles `SortyKit` directly and runs with no
app process, no simulator UI and no network. That is why sorting, decoding,
PKCE, launch gating and save behaviour are all testable cheaply, and why logic
belongs in `SortyKit` rather than in a view.

**User-facing copy is a testable layer.** Anything a screen *says* — empty
states, row text, badges, unrankable-group reasons, every word in Settings — is
decided in `SortyKit` where a test can assert on it. Views render what they are
handed. A string literal typed into a view is a bug in the making.

## Screenshots

```bash
./scripts/screenshots.sh          # every screen, headless
SETTLE=6 ./scripts/screenshots.sh # slower machine
```

**Never drive the simulator GUI.** Every screen is reached from a cold launch
through the DEBUG-only `DebugLaunch` arguments and captured with
`simctl io screenshot`, which is what keeps the harness runnable while the Mac
is being used for something else. `scripts/screenshots.sh` replaces
`screenshots/` wholesale, so a screen that no longer exists cannot leave a stale
PNG behind pretending it does.

Review that set by looking at it, not by hashing it — the header of the script
explains what does and does not reproduce, and why.

## Decisions

Architecture decisions live in [`docs/adr/`](docs/adr/); vocabulary lives in
[`CONTEXT.md`](CONTEXT.md). Both are read by people and agents working here, so
they are load-bearing rather than ceremonial.

Write an ADR when a change makes a decision someone could reasonably reverse
later — a fixed set becoming a different size, a pattern being adopted, a
capability being dropped. Number it next in sequence, title it as a sentence
saying what was decided, and record what was *considered and rejected*, not just
what was chosen. Amend or supersede an old ADR rather than deleting it. Add the
row to the ADR table in the README.

Issues and specs live as markdown under `.scratch/`, which is gitignored — see
[`AGENTS.md`](AGENTS.md) and [`docs/agents/`](docs/agents/).

## Versions

Set through the helper, never by hand and never in Xcode:

```bash
./scripts/version.sh             # read it
./scripts/version.sh set 0.2.0   # write it
```

A normal PR does not touch the version. Bumping it is part of cutting a release
or shipping a hotfix, both in [RELEASING.md](RELEASING.md).

## Licence

Sorty is GPL-3.0. Contributions are accepted under the same licence.

Sorty is an independent reimplementation of
[Sort Your Music](https://github.com/plamere/SortYourMusic) by
[Paul Lamere](https://github.com/plamere) — **no code from it is used or
included**, and none should be. The idea is credited; the implementation is
ours.
