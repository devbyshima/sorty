## What changes, and why

<!-- The intent, not the file list. The diff already lists the files. -->

## Target branch

<!-- Delete the ones that do not apply. -->

- [ ] `main` — new work. **Any feature goes here and only here.**
- [ ] `release/X.Y` — a bug fix for a version being stabilised. No features.
- [ ] This is a hotfix, and `release/X.Y` above is the **oldest** affected
      release branch. I will propagate it forward per
      [RELEASING.md](../RELEASING.md#propagate-a-hotfix-forward).

## Checks

- [ ] Tests cover the change, or it is not testable in `SortyKit` and I said why
- [ ] Any copy a screen shows is decided in `SortyKit`, not typed into a view
- [ ] `CHANGELOG.md` has an `## [Unreleased]` entry, or a listener would not notice this
- [ ] `project.yml` edited rather than `Sorty.xcodeproj`, and `xcodegen generate` run
- [ ] Screenshots regenerated with `./scripts/screenshots.sh` if any screen moved
- [ ] An ADR is added or amended if this makes or overturns a decision
