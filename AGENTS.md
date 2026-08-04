# Sortify

iOS SwiftUI app that reorders a Spotify playlist by the musical character of its
tracks and saves the result back to Spotify.

- `SortifyKit/` — models, arrangement logic, Spotify and audio-feature clients,
  view models. Everything testable lives here.
- `Sortify/` — SwiftUI views and app lifecycle.
- `Tests/` — Swift Testing suites against `SortifyKit`.

The Xcode project is generated. After editing `project.yml`, run
`xcodegen generate`. Do not hand-edit `Sortify.xcodeproj`.

Verify UI changes with headless screenshots via `scripts/screenshots.sh`, which
drives the simulator through `DebugLaunch` launch arguments. Do not drive the
simulator GUI.

## Agent skills

### Issue tracker

Issues and specs live as markdown files under `.scratch/<feature>/` in this
repo. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each label string equal to its name. See
`docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` at the repo root plus `docs/adr/`. See
`docs/agents/domain.md`.
