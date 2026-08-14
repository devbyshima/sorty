# Releasing Sorty

How a change gets from `main` to a device, and how a fix gets to everyone who
already has one.

Sorty is an iOS app, so it releases like one: **release branches and pre-release
tags, no feature flags.** A web service can ship a half-built feature dark and
switch it on per environment; an app cannot, because the binary in a listener's
hand is whatever was signed weeks ago. What replaces the flag is the release
branch — a place where a version stops changing shape and only gets less broken.

- [Channels](#channels)
- [Versioning](#versioning)
- [Protected branches](#protected-branches)
- [Cut a release branch](#cut-a-release-branch)
- [Run a beta](#run-a-beta)
- [Promote to production](#promote-to-production)
- [Ship a hotfix](#ship-a-hotfix)
- [Propagate a hotfix forward](#propagate-a-hotfix-forward)
- [What CI does](#what-ci-does)
- [Signing secrets](#signing-secrets)

## Channels

| Channel | Branch | Tag | Built by | Reaches |
|---|---|---|---|---|
| **dev** | `main` | none | `ci.yml` on every push and PR | you, and agents working in the repo |
| **beta** | newest `release/X.Y` | `vX.Y.Z-beta.N` | `beta.yml` on every push | TestFlight |
| **production** | stable `release/X.Y` | `vX.Y.Z` | `release.yml` on the tag | a GitHub Release, and the App Store once Apple opens submissions |

`main` is the trunk. All new feature work happens there and nowhere else.

A `release/X.Y` branch takes **bug fixes only**. Not a small feature, not a
tempting one-line improvement, not a copy change that "is basically a fix". The
rule is worth its rigidity: the value of a release branch is entirely that you
know what is on it, and one exception costs you that.

> [!NOTE]
> **Production does not yet mean the App Store.** Sorty targets iOS 27, and
> App Store submission still requires Xcode 26 and an iOS 26 SDK — Xcode 27
> builds are TestFlight-only until Apple opens submissions. Until then a
> production tag means a signed archive and a published GitHub Release, and
> TestFlight is where builds reach people. When submissions open, the upload
> step in `release.yml` is the only thing that changes.

## Versioning

[Semantic Versioning](https://semver.org). For an app with no server of its own:

- **MAJOR** — stored state or a Spotify connection cannot carry across. A scope
  change forcing a reconnect; a preference that cannot be migrated.
- **MINOR** — an arrangement, a screen, or an ability is added.
- **PATCH** — behaviour is fixed, nothing is added.

**The version lives in `project.yml` and nowhere else.** `Sorty.xcodeproj` is
generated and gitignored, so a version typed into Xcode's UI survives until the
next `xcodegen generate` and then vanishes. Read and write it through the helper:

```bash
./scripts/version.sh                  # 0.1.0
./scripts/version.sh build            # 1
./scripts/version.sh set 0.2.0        # writes MARKETING_VERSION
./scripts/version.sh check v0.2.0     # asserts a tag agrees; CI runs this
```

Two numbers, and they are not the same thing:

| | | |
|---|---|---|
| `MARKETING_VERSION` | `CFBundleShortVersionString` | The SemVer humans read. Apple accepts **one to three dot-separated integers and nothing else** — `0.2.0-beta.1` is rejected at upload. |
| `CURRENT_PROJECT_VERSION` | `CFBundleVersion` | The build number. Must strictly increase within a version train or TestFlight rejects the upload as a duplicate. |

So **a pre-release suffix lives only in the git tag.** `v0.2.0-beta.1` and
`v0.2.0` are both built from `MARKETING_VERSION = 0.2.0`; what distinguishes the
builds is the build number, which CI stamps as a UTC timestamp
(`20260813.1530`). A timestamp rather than a counter because Beta and Release are
separate workflows with separate run numbers, and a shared counter they can both
increment is a race that ends in a rejected upload.

## Protected branches

Ruleset **"Trunk and release branches"** covers `refs/heads/main` and
`refs/heads/release/*`. It forbids deletion and non-fast-forward, and requires
the `Repository checks` status. Two consequences shape every recipe below, and
both are easy to learn the hard way.

**A required status check gates pushes, not merely merges.** There is no
"require a pull request" rule here, but the status check achieves the same
thing: a commit you wrote a moment ago has no check status, so pushing it
straight to `main` or a release branch is refused —

```
GH013: Required status check "Repository checks" is expected.
```

So **nothing reaches `main` or `release/*` except through a pull request**, where
`ci.yml` runs on `pull_request` and produces the status the rule wants. That
includes commits nobody would think of as a change under review: a version bump,
a changelog date, a merge resolving `project.yml`.

**The rule is enforced on branch creation too** (`do_not_enforce_on_create` is
false), which is the one that surprises. You cannot create `release/0.2` by
pushing a branch whose tip you just wrote: the check cannot run until the ref
exists, and the ref cannot be created until the check has run. The way out is to
create the branch at a commit that **already carries a passing check** — the tip
of `main`, which earned one when it landed — and let every later commit arrive by
PR.

Tags are untouched. The ruleset's target is branches, so `git push origin
v0.2.0` needs no ceremony.

> [!NOTE]
> `--admin` does not help. The ruleset's `bypass_actors` is empty and
> `current_user_can_bypass` is `never`, so no one bypasses it, repository owner
> included. That is deliberate — a bypass nobody uses is a bypass nobody
> audits — but it means the answer to a refused push is always a PR, never a
> flag.

## Cut a release branch

When `main` is ready to stabilise. Say the next version is **0.2.0**.

A cut costs **two pull requests**: one carrying the version onto the new branch,
one moving `main` past it. See [Protected branches](#protected-branches) for why
none of this can be a plain push.

```bash
git checkout main
git pull

# 1. Create the branch AT MAIN'S TIP, and commit nothing yet. That commit
#    already carries a passing check; anything you write here would not, and
#    the ref could never be created. See Protected branches.
git push origin main:refs/heads/release/0.2
git fetch origin
```

The branch now exists, at the same commit as `main`, and `beta.yml` has already
built it once. Give it its version:

```bash
# 2. Set the version this release branch will carry.
git checkout -b release-prep/0.2.0 origin/release/0.2
./scripts/version.sh set 0.2.0

# 3. Rename the changelog's Unreleased section to this version.
#    Add a new empty Unreleased above it, and update the link refs at the foot.
#    Leave it undated — it gets its date when it is promoted.
$EDITOR CHANGELOG.md

git commit -am "Sorty 0.2.0"
git push -u origin release-prep/0.2.0
gh pr create --base release/0.2 --title "Sorty 0.2.0"
```

Merging that PR triggers `beta.yml` again, on the branch as it will actually
ship.

Then move `main` on, so a dev build never claims to be the version stabilising
next to it. Branch from the prep branch rather than from `main`, so trunk
receives the changelog rename as well as its own next version:

```bash
git checkout -b main-is-0.3.0 release-prep/0.2.0
./scripts/version.sh set 0.3.0
git commit -am "main is 0.3.0 now"
git push -u origin main-is-0.3.0
gh pr create --base main --title "main is 0.3.0 now"
```

Both PRs need `Repository checks` to pass, which takes seconds on Linux. The
macOS test job will be red; it is advisory, and [What CI does](#what-ci-does)
explains why.

> [!IMPORTANT]
> The branch is `release/0.2` — **minor only, no patch component**. Every
> `0.2.x` release is tagged on this one branch. `release/0.2.1` would strand
> 0.2.0's fixes on a branch nothing merges from.

## Run a beta

Every commit that lands on `release/0.2` already produces a build. A tag is how
you mark one as the beta people should install. Tags are not covered by the
ruleset, so this section is the one place you still push directly.

```bash
git checkout release/0.2
git pull

# The tag's version must match project.yml. Check before you tag.
./scripts/version.sh check v0.2.0-beta.1

git tag -a v0.2.0-beta.1 -m "Sorty 0.2.0 beta 1"
git push origin v0.2.0-beta.1
```

`release.yml` publishes it as a GitHub **pre-release**, so it never takes the
"Latest" badge from a real release.

Fixes found in beta go onto `release/0.2` as normal bug fixes, then
`v0.2.0-beta.2`, and so on. Nothing about the beta number touches
`project.yml` — it is a tag concern only.

## Promote to production

When the beta has stopped producing fixes:

```bash
git checkout release/0.2
git pull

# Date the changelog section — it has been sitting there unreleased.
git checkout -b date-the-0.2.0-changelog
$EDITOR CHANGELOG.md    # "## [0.2.0] - 2026-09-01"
git commit -am "Date the 0.2.0 changelog"
git push -u origin date-the-0.2.0-changelog
gh pr create --base release/0.2 --title "Date the 0.2.0 changelog"
```

**Tag only once that PR is merged**, and tag the merged commit — a tag on the
branch tip before the date lands publishes a Release whose notes have no date in
them:

```bash
git checkout release/0.2
git pull

./scripts/version.sh check v0.2.0
git tag -a v0.2.0 -m "Sorty 0.2.0"
git push origin v0.2.0
```

`release.yml` verifies the tag against `project.yml`, refuses to publish if
`CHANGELOG.md` has no section for the version, builds, and publishes the Release
with that section as its notes.

Then carry the dated changelog back to `main` so history agrees with itself:

```bash
git checkout main
git pull
git checkout -b carry-0.2.0-back
git merge --no-ff release/0.2
# Resolve project.yml in main's favour — see the warning below.
git push -u origin carry-0.2.0-back
gh pr create --base main --title "Carry the 0.2.0 changelog back to main"
```

The merge happens on a branch rather than on `main` itself for the same reason
everything else does: a merge commit is a commit, and it reaches `main` only
through a PR. This is the better place for it anyway — a conflict resolved on a
branch can be reviewed, and one resolved on `main` cannot.

`release/0.2` is now the production branch. It stays alive as long as anyone
runs 0.2.x.

## Ship a hotfix

**Fix it on the oldest release branch that has the bug.** Not on `main`, not on
the newest branch — the oldest affected one, so the fix can travel forward to
every branch that inherited it. A fix made on the newest branch cannot go
backwards without a cherry-pick you will forget to make.

Say 0.1.1 fixes a crash that exists in 0.1.0 and also in the unreleased 0.2:

```bash
git checkout release/0.1
git pull
git checkout -b hotfix/0.1.1-crash-on-empty-playlist
```

Fix it. Write the test that fails without the fix. Then:

```bash
./scripts/version.sh set 0.1.1
$EDITOR CHANGELOG.md      # a new "## [0.1.1] - <date>" section, Fixed
git commit -am "Fix the crash on an empty playlist"
git push -u origin hotfix/0.1.1-crash-on-empty-playlist
```

```bash
gh pr create --base release/0.1 --title "Fix the crash on an empty playlist"
```

Merge it through GitHub — `release/0.1` takes no direct push, merge commit
included. Then tag the merged commit:

```bash
git checkout release/0.1
git pull

./scripts/version.sh check v0.1.1
git tag -a v0.1.1 -m "Sorty 0.1.1"
git push origin v0.1.1
```

**Then propagate it forward immediately** — before the branch leaves your head.

## Propagate a hotfix forward

The whole point of fixing on the oldest branch. Walk the branches in order,
oldest to newest, ending at `main`:

```
release/0.1  →  release/0.2  →  main
```

Merge rather than cherry-pick where you can. A merge records in the graph that
the fix arrived, so `git branch --contains` can prove it later; a cherry-pick
creates a new commit that looks unrelated.

Each step is a merge onto a protected branch, so each step is a PR. Resolve the
conflict on the branch, where the resolution can be read:

```bash
git checkout release/0.2
git pull
git checkout -b propagate-0.1.1-to-0.2
git merge --no-ff release/0.1
# ... resolve, see below ...
git push -u origin propagate-0.1.1-to-0.2
gh pr create --base release/0.2 --title "Propagate 0.1.1 into 0.2"

# then, once that is merged:
git checkout main
git pull
git checkout -b propagate-0.1.1-to-main
git merge --no-ff release/0.2
# ... resolve ...
git push -u origin propagate-0.1.1-to-main
gh pr create --base main --title "Propagate 0.1.1 into main"
```

Wait for each PR to merge before opening the next. Merging `release/0.2` into
`main` before the fix has actually reached `release/0.2` propagates nothing,
quietly.

> [!WARNING]
> **`project.yml` will conflict every single time, and the resolution is always
> the same: keep the receiving branch's version.** `release/0.1` says 0.1.1 and
> `release/0.2` says 0.2.0; merging the first into the second must leave 0.2.0
> standing. Take the wrong side and `release/0.2` starts building 0.1.1, its
> tag check fails, and the cause is three merges back.
>
> ```bash
> # after a conflicted merge, on release/0.2:
> ./scripts/version.sh set 0.2.0     # the RECEIVING branch's version
> git add project.yml
> git commit
> ```
>
> `CHANGELOG.md` conflicts the same way. Keep both sections — the 0.1.1 one
> belongs in the history of every later branch too.

When the branches have diverged too far to merge cleanly, cherry-pick the single
commit and **record where it came from**:

```bash
git checkout main
git pull
git checkout -b cherry-pick-the-empty-playlist-fix
git cherry-pick -x <sha-of-the-fix>    # -x writes the source SHA into the message
git push -u origin cherry-pick-the-empty-playlist-fix
gh pr create --base main --title "Cherry-pick the empty-playlist fix"
```

Then verify the fix is genuinely everywhere. This is the check that makes "fixes
are never lost" a fact rather than an intention:

```bash
git branch -a --contains <sha-of-the-fix>
```

Every live release branch and `main` should be listed. If one is missing, it
ships the bug.

## What CI does

Nothing here required existing CI to change — there was none. Three workflows:

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | PR and push to `main`, `release/**` | Repository checks (blocking) and the test suite (advisory) |
| `beta.yml` | push to `release/**` | Beta build; TestFlight upload when secrets exist |
| `release.yml` | tag `v*` | Verifies the tag, builds, publishes the GitHub Release |

**The test job does not block yet, on purpose.** Sorty targets iOS 27 with
Xcode 27, and GitHub's hosted images carry whatever Apple has shipped them,
which lags. A required check that goes red for a reason unrelated to the change
under review teaches everyone to ignore it. So it reports and stays advisory.

The blocking job is `checks`, which runs on Linux in seconds and asserts what is
true regardless of toolchain: `project.yml` parses, the version helper agrees
with it, `Sorty.xcodeproj` is not tracked, and the scripts are executable and
syntactically valid.

**When `xcodebuild` on a hosted runner goes green on its own**, delete
`continue-on-error` from the `test` job in `ci.yml` and add `Tests (advisory)` —
renamed, by then — to the required checks of the ruleset described under
[Protected branches](#protected-branches). That is the entire migration. If Apple's runner
images never catch up, register a self-hosted runner on a Mac that has Xcode 27
and change `runs-on`.

## Signing secrets

The signed paths in `beta.yml` and `release.yml` are inert until these exist
under **Settings → Secrets and variables → Actions**. Without them both
workflows still build unsigned, which catches every compile and link error a
signed build would.

| Secret | What |
|---|---|
| `APPLE_CERTIFICATE_P12` | `base64 -i dist.p12` — the Apple Distribution certificate |
| `APPLE_CERTIFICATE_PASSWORD` | its export password |
| `APPLE_PROVISIONING_PROFILE` | `base64 -i Sorty.mobileprovision` — an App Store profile for `com.fulltimestudio.sorty` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APP_STORE_CONNECT_ISSUER_ID` | on the same page |
| `APP_STORE_CONNECT_KEY_P8` | `base64 -i AuthKey_XXXX.p8` — downloadable exactly once |

```bash
base64 -i dist.p12 | pbcopy          # then paste into the secret
```

> [!CAUTION]
> This repository is public. Fork pull requests do not receive secrets, which is
> correct and should stay that way — never move a signing step into `ci.yml`,
> which runs on PRs.
