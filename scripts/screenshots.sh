#!/bin/bash
# Headless screenshots of every screen, on the iOS 27 simulator.
#
# Deliberately never drives the simulator GUI. Every screen is reached from a
# *cold launch* through the `DebugLaunch` arguments and captured with `simctl io
# screenshot`, which is what keeps this runnable while the Mac is being used for
# something else.
#
# **What reproduces, and what does not.** The app is deterministic: the demo
# catalogue is generated from a fixed seed, the install is fresh so nothing
# persisted by the previous run survives, and two launches of the same shot
# produce identical pixels. The *screenshots* are not byte-identical between
# runs, and chasing that is not worth it - measured, the residue is two things,
# neither of them Sorty:
#
#   - The Dynamic Island region, 378x112px at (414,41), flips wholesale between
#     runs. A simulator artifact.
#   - Antialiasing noise in artwork and text, a handful of channel steps over
#     ~1,500 pixels. Two shots in the set differ by nothing above 3.
#
# So review this set by looking at it, not by hashing it. What *must* never
# change without intent is content, and that is what the two guards below are
# for: the fresh install, and every library shot naming its layout. Before them,
# `-layout` wrote through to a stored preference and the set silently showed
# whatever layout the *last* run ended on - which is how `01-playlists` changed
# from a grid to a list inside a commit about the playlist header. It went
# unnoticed because the clock made every shot differ every run anyway, so a real
# change looked like more of the same noise. Hence the frozen status bar.
#
# That constraint is also why the arguments look the way they do. A sheet opens
# on a tap and the harness never taps, so it has to be able to *arrive*
# presented - hence `-sheet`, `-track`, `-connectStep`. An Arrangement is named
# as one thing (`-arrangement bpm-descending`) rather than as a column plus a
# direction, because a column and a direction could name a combination that
# doesn't exist.
#
#   ./scripts/screenshots.sh          # the whole set
#   SETTLE=6 ./scripts/screenshots.sh # slower machine
#   DEVICE="iPhone 17" OS=27.0 ./scripts/screenshots.sh
set -euo pipefail

DEVICE="${DEVICE:-iPhone 17 Pro}"
OS="${OS:-27.0}"
BUNDLE_ID="com.fulltimestudio.sorty"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/screenshots}"

# Staged, then swapped in. A screen that no longer exists must not leave its
# screenshot behind pretending it does - replacing the whole directory at the
# end rather than writing over it makes that structural instead of a chore.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> Building"
xcodebuild -project "$ROOT/Sorty.xcodeproj" -scheme Sorty \
  -destination "platform=iOS Simulator,name=$DEVICE,OS=$OS" \
  -configuration Debug -derivedDataPath "$ROOT/.build" build >/dev/null

APP="$ROOT/.build/Build/Products/Debug-iphonesimulator/Sorty.app"

UDID=$(xcrun simctl list devices available -j \
  | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next(x['udid'] for k,v in d.items() if 'iOS-${OS//./-}' in k for x in v if x['name']=='$DEVICE'))")

echo "==> Booting $DEVICE ($UDID)"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null

# Uninstall before installing, every time. The app persists library preferences,
# and `-layout` writes through to that store rather than overriding it for one
# launch - so the last layout any shot asked for became the layout every
# *unqualified* shot in the next run started from. That is how `01-playlists`
# silently changed from a grid to a list between two commits that had nothing to
# do with the library. A run must not inherit anything from the run before it.
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP"

# Freeze the status bar. Every shot includes it, and the clock reads wall time,
# so without this no two runs can ever produce the same pixels no matter how
# deterministic the app is - which is what hid the layout bug above: the whole
# set changed on every run anyway, so one screen quietly changing layout looked
# like more of the same noise. 9:41 is Apple's own convention.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi >/dev/null 2>&1 || true

# Change a simulator-wide UI setting and wait for it to land.
#
# `simctl ui` returns as soon as the request is *sent*, not once the system has
# applied it, and `shoot` terminates and relaunches the app immediately. That
# race silently produced a wrong screenshot: `20-track-detail-stacked` is meant
# to be at accessibility-large and was captured still at the
# accessibility-extra-extra-extra-large left over from the shot before it, so the
# set carried a picture of the wrong text size and looked like a real change in
# the next diff. Always go through this rather than calling `simctl ui` directly.
ui() {
  xcrun simctl ui "$UDID" "$@"
  sleep "${UI_SETTLE:-2}"
}

# A capture is only kept if it has a screen on it.
#
# **`simctl io screenshot` intermittently returns a blank white frame**, and it
# does so silently: exit status 0, a valid PNG, the right dimensions. Measured
# over two full runs, about four shots in forty-eight came back this way, a
# different four each time - so it is a race in the capture rather than anything
# about a particular screen. Without this check those four land in the set as
# though they were what the app looks like, and the swap at the end of this
# script then publishes them.
#
# The test is deliberately blunt: standard deviation over the body of the frame.
# A blank capture measures exactly 0.0, and the quietest real shot in the set
# (`20-track-detail-stacked`) measures 10.9, so anything under 3 is a blank and
# nothing else. Relaunching is what fixes it; a second capture of the same
# process usually comes back blank too.
#
# Pillow and numpy are not in the standard library, and this script otherwise
# needs nothing but python3, so their absence must not break the harness for
# somebody who just cloned the repo. Without them it falls back to the PNG's
# compressed size, which measures the same property less precisely: image
# entropy. Measured across two full runs, blank frames land at 75-81KB and the
# smallest real shot in the set (`00-signed-out`) at 212KB, so the floor sits
# with room on both sides.
looks_blank() {
  python3 - "$1" <<'PY'
import os, sys

path = sys.argv[1]
try:
    from PIL import Image
    import numpy as np
except ImportError:
    sys.exit(0 if os.path.getsize(path) < 150_000 else 1)

a = np.asarray(Image.open(path).convert("L"))
sys.exit(0 if a[300:2400].std() < 3 else 1)
PY
}

shoot() {
  local name="$1"; shift
  echo "==> $name"
  local attempt
  for attempt in 1 2 3; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" >/dev/null
    sleep "${SETTLE:-4}"
    xcrun simctl io "$UDID" screenshot --type=png "$STAGE/$name.png" >/dev/null
    if ! looks_blank "$STAGE/$name.png"; then return 0; fi
    echo "    blank capture, retrying ($attempt/3)"
  done
  echo "!!! $name came back blank three times - not writing the set" >&2
  exit 1
}

# ─── Light, default text size ────────────────────────────────────────────────

# The way in. Shown whenever no account is connected, which after ADR-0007 is
# the state a first run begins in - so this one is shot *without* `-demo`, since
# the whole point is what someone sees before there is anything to see.
shoot 00-signed-out        -screen signedOut

# Everything past the way-in screen runs against the bundled catalogue, which
# ADR-0007 keeps for exactly this. `-demo` is the only way into it and nothing
# in a release build can reach it.
shoot 01-playlists         -demo -screen playlists
shoot 02-tracks-order      -demo -screen tracks -playlist demo-longrun
shoot 03-tracks-bpm        -demo -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 04-tracks-asep       -demo -screen tracks -playlist demo-mixed -arrangement artist-separation
# Shuffle is the one chip carrying a second control, so it gets its own shot.
shoot 05-tracks-shuffle    -demo -screen tracks -playlist demo-longrun -arrangement shuffle
# An Arrangement outside the pinned five: it should trail the row and be
# scrolled into view, or picking it would select a chip nobody can see.
shoot 06-tracks-offpiste   -demo -screen tracks -playlist demo-longrun -arrangement valence-descending
# Tracks the Arrangement can't place. The tempo range leaves a few ranked tracks
# on screen as well, because the case worth seeing is the common one - where
# *some* tracks were placed and some weren't, which the old all-or-nothing
# notice never fired for.
shoot 07-tracks-unrankable -demo -screen tracks -playlist demo-mixed -arrangement bpm-ascending -filter 140-160

# Every Attribute across one track - the half of the old table the list can't
# do, and the reason ADR-0001's trade was acceptable.
shoot 08-track-detail      -demo -screen tracks -playlist demo-longrun -sheet track -track 0
# Position 22 of demo-mixed by BPM is past the ranked tracks: one the feature
# source had nothing for. Every audio feature should read "Unavailable" and draw
# no bar, while Spotify's own values still do.
shoot 09-track-detail-missing -demo -screen tracks -playlist demo-mixed -arrangement bpm-ascending -sheet track -track 22
shoot 10-arrangements      -demo -screen tracks -playlist demo-longrun -sheet arrangements

# The guided connect flow. Later steps are reached by tapping Continue, so the
# two carrying something to get wrong - the redirect URI and the Client ID -
# have to be nameable directly.
shoot 11-connect-why       -demo -screen connect
shoot 12-connect-app       -demo -screen connect -connectStep createApp
shoot 13-connect-id        -demo -screen connect -connectStep clientID

# The library has three layouts. `01-playlists` above is the only shot that
# passes no `-layout` at all, which is deliberate: it is the one that proves what
# the default resolves to (two-up, ADR-0009). Every other library shot names its
# layout, so no shot's appearance depends on the order the set is taken in.
#
# This one is now the same layout as `01` and is kept because it is the only
# place the pair can be compared once the others start varying text size and
# Appearance.
shoot 14-playlists-two-up  -demo -screen playlists -layout grid2

shoot 15-settings          -demo -screen settings
shoot 16-faq               -demo -screen faq

# ─── Largest text size ───────────────────────────────────────────────────────
# The old table simply clipped here, which is the failure the redesign exists to
# end. Nothing may truncate; everything may wrap.
echo "==> largest text size"
ui content_size accessibility-extra-extra-extra-large
shoot 17-tracks-large-text       -demo -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 18-track-detail-large-text -demo -screen tracks -playlist demo-longrun -sheet track -track 0
shoot 19-playlists-large-text    -demo -screen playlists -layout grid2

# ─── One step into the accessibility sizes ───────────────────────────────────
# Both screens take their stacked layout from here on, and this is the smallest
# size at which the stacked content is actually on screen: at the maximum the
# header fills it, and the harness can't scroll.
echo "==> accessibility-large"
ui content_size accessibility-large
shoot 20-track-detail-stacked -demo -screen tracks -playlist demo-longrun -sheet track -track 0
shoot 21-playlists-stacked    -demo -screen playlists -layout grid2
ui content_size medium

# ─── Dark ────────────────────────────────────────────────────────────────────
# First-class, not an afterthought: the accent has its own value there
# (ADR-0006) and the bars are drawn against a different surface.
echo "==> dark appearance"
ui appearance dark
shoot 22-dark-playlists    -demo -screen playlists -layout grid2
shoot 23-dark-tracks       -demo -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 24-dark-track-detail -demo -screen tracks -playlist demo-longrun -sheet track -track 0
shoot 25-dark-connect      -demo -screen connect -connectStep createApp
ui appearance light

# ─── Scrolled ────────────────────────────────────────────────────────────────
# The progressive blur exists only where content passes *under* a header, so
# every shot above proves nothing about it: at rest there is nothing behind the
# blur to smear. These three are the only ones that show it working, and they
# are the ones to look at when it goes wrong - it fails by blurring the header
# instead of the content, which is invisible until something has scrolled.
#
# The library needs a large text size to have anything to scroll at all: seven
# playlists in a three-up grid fit the screen with room to spare.
#
# The playlist screen gets two, because its blur has two states. Mid-scroll the
# chip row is still travelling and the fade under the navigation bar is what
# the cover passes through. Once the row pins, that fade is given up and the
# row's own blur carries the band instead, so the two together read as one
# solid region and one fade. The thing to check in the pinned shot is that the
# chips themselves are perfectly sharp: they sit under an overlay that draws
# above them, and a fade left switched on up there blurs the control.
echo "==> scrolled"
shoot 26-tracks-scrolled -demo -screen tracks -playlist demo-longrun -scrolled 240
shoot 27-tracks-pinned -demo -screen tracks -playlist demo-longrun -scrolled 700
shoot 28-track-detail-scrolled -demo -screen tracks -playlist demo-longrun -sheet track -track 0 -scrolled 120
ui content_size accessibility-extra-extra-extra-large
shoot 29-playlists-scrolled -demo -screen playlists -layout grid2 -scrolled 420
ui content_size medium

# ─── Withheld ────────────────────────────────────────────────────────────────
# Another listener's playlist, which Spotify names but never opens (ADR-0008).
# The library shot above already carries the row for it, mark and all; this is
# what happens when someone taps it anyway. Appended rather than filed with the
# playlist screens so that adding it renames none of the set above.
echo "==> withheld"
shoot 30-tracks-withheld -demo -screen tracks -playlist demo-borrowed
# The list is the layout that spells its marks out: the grids show a badge as a
# glyph and no count at all, so "Can't open" and "Track count hidden" are words
# no other shot in this set contains.
shoot 31-playlists-list -demo -screen playlists -layout list

# ─── Attribution ─────────────────────────────────────────────────────────────
# The Spotify mark at the foot of both list screens, which is mandatory wherever
# their metadata is shown and which nothing else in this set can see: it sits
# below the last row, and every other shot stops above it.
#
# It is here because it was *silently lost* once already - the library and
# track-list rebuild in `32b9a9c` replaced the containers it sat in, and no shot
# in the set could have caught that. These two can.
#
# Scrolled by an absurd offset on purpose: `scrollTo(y:)` clamps to the content,
# so this reliably means "the bottom" for a list of any length. `scrollTo(edge:)`
# is not the same thing and was tried - with a tall `safeAreaInset` header it
# lands past the content and this shot comes back empty.
#
# The withheld-playlists footer sits *above* the mark rather than below it, for
# this shot's sake: whatever is last is what scrolling to the bottom finds.
#
# One in each appearance, because the mark is not one image. The guidelines
# require monochrome on a background that is neither black nor white, so the
# catalogue carries Spotify's black file and their white one and the appearance
# picks. **What to check is that the dark shot shows a white logo** - if it
# renders black it has vanished into a #0D0D0D background, and that failure is
# invisible to anything but the eye.
echo "==> attribution"
ui content_size accessibility-extra-extra-extra-large
shoot 32-playlists-attribution -demo -screen playlists -layout grid2 -scrolled 99999
ui content_size medium
ui appearance dark
shoot 33-dark-tracks-attribution -demo -screen tracks -playlist demo-longrun -scrolled 99999
ui appearance light

# ─── Shaders ─────────────────────────────────────────────────────────────────
# Two Metal effects, and **neither can be seen in any other shot in this set**,
# because both live in states that are over before a screenshot could land.
#
# The splash is a state, not a destination: it lasts exactly as long as
# `restore()`, which against the demo catalogue is no time at all. `-screen
# splash` holds it.
#
# The cover ripple replaces the spinner on a cover that has not arrived, and
# demo covers are drawn on device in a frame or two. `-pendingCovers` stops
# every cover resolving for the whole launch, so the placeholder is all there
# is to photograph.
#
# What to check is that either shot shows anything at all. A `[[stitchable]]`
# function that fails to resolve at runtime does not crash and does not warn -
# the effect is simply skipped, and what is left looks like a perfectly
# reasonable flat tile. These shots are the only thing between that and
# shipping it.
# The onboarding's page transition is **not** in this set and cannot be, because
# a transition is not a screen. Verifying one needs a burst across a step change:
#
#   xcrun simctl launch $UDID com.fulltimestudio.sorty \
#     -demo -screen connect -connectStep why -advanceAfter 6
#   # then ~8 screenshots back to back, starting about 7.3s in
#
# `-advanceAfter` drives one step change. `simctl io screenshot` takes about
# 0.25s to return, so a burst at a transition's real speed lands on either side
# of the whole thing - measured, twice - and the argument slows the change to
# make it photographable at all.
#
# A single frame appended to this set would be worse than nothing: it would be
# whichever moment the timing happened to land on, and would differ every run.
echo "==> shaders"
shoot 34-splash -demo -screen splash
shoot 35-covers-pending -demo -screen playlists -layout grid2 -pendingCovers
ui appearance dark
shoot 36-dark-splash -demo -screen splash
ui appearance light

# ─── The last connect step ───────────────────────────────────────────────────
# Step 4 was the only one of the four this set never photographed, which is how
# it went unnoticed that nothing distinguished it from step 3. Appended rather
# than filed with 11-13, for the same reason the withheld shots are: inserting
# it there would renumber half the set for one addition.
shoot 37-connect-authorize -demo -screen connect -connectStep authorize
# The info sheet, which opens on a tap the harness never makes. Shot over step 1
# because that step's answer is the longest of the four - three cards - so this
# is the shape at its most demanding.
shoot 38-connect-detail -demo -screen connect -connectStep why -connectDetail
# The same sheet over step 2, which is the only one carrying a value rather than
# only prose. The redirect URI is *here* and nowhere else in the interface, so
# a change that loses it has to be visible in this set or it ships unnoticed.
shoot 39-connect-app-detail -demo -screen connect -connectStep createApp -connectDetail
# The dashboard, opening. Two things in one shot, neither reachable otherwise:
# the create-app button's *second* state - green, "Open the Spotify Dashboard",
# which only appears after a tap - and the consent alert that buys the shared
# cookie jar. The browser is an `ASWebAuthenticationSession`, and a session that
# declines to start does it silently, so this is also the only evidence in the
# set that the page opens at all.
shoot 40-connect-dashboard -demo -screen connect -connectStep createApp -dashboard

# ─── Settings, as a page ─────────────────────────────────────────────────────
# Settings stopped being a sheet and became a pushed page with three of its own
# behind it (ADR-0017 removed a fourth section along the way). `-screen` pushes
# the whole stack rather than the visible screen, so the back chevron in these
# shots behaves as it will in a shipped build.
#
# `15-settings` above is the root. These are what it can reach - none of them
# was photographable at all while Settings was one long Form.
echo "==> settings"
shoot 41-settings-spotify-app -demo -screen spotifyApp
shoot 42-settings-audio-features -demo -screen audioFeatures
# The credit. It used to be three lines below fourteen collapsed questions
# inside a sheet opened from another sheet, which is why this shot exists: the
# whole point of the change is that Paul Lamere's name is one tap from Settings.
shoot 43-settings-credits -demo -screen credits

# ─── What hasn't arrived ─────────────────────────────────────────────────────
# The placeholders of ADR-0019, and like the two shaders above **none of them is
# visible in any other shot in this set** - the demo catalogue is fully loaded
# before a screenshot could land, which is the same reason `-pendingCovers`
# exists. `-stallLibrary` holds the pages back.
#
# **What to check is that nothing moves between a pair.** Open `44` and `01` and
# flip between them: the covers are the same size at the same corner, the name
# block reserves the same two lines, and the row pitch is identical. A
# placeholder whose geometry drifts from the row it stands in for causes a
# reflow at the handoff, which is the one thing the whole decision exists to
# prevent - and it is invisible in either shot alone.
echo "==> placeholders"
#
# `-stallLibrary` holds every page *after* the first, on purpose: the first one
# still has to land or the launch gate never opens and this is a photograph of
# the splash. The splash waiting on a real library is `34-splash`, which is the
# same composition reached the other way.
shoot 44-playlists-pending -demo -screen playlists -layout grid2 -stallLibrary 30
# And the track list needs its *own* argument, because `restore()` awaits the
# whole library load and the harness navigates after it - so stalling the
# library here would stall the navigation and never leave the library.
shoot 45-tracks-pending -demo -screen tracks -playlist demo-longrun -stallTracks 30

# ─── Spotify's own ───────────────────────────────────────────────────────────
# The refusal every listener meets, which no shot in this set has ever carried:
# the demo catalogue used to open Discover Weekly perfectly, so the words
# `LoadFailure` gives a Spotify-owned playlist were only ever read in a test.
shoot 46-tracks-spotifys-own -demo -screen tracks -playlist 37i9dQZEVXcDEMOWEEKLY1
# The line counting playlists Spotify listed and would not name. It sits between
# the last row and the attribution mark - **above** it, never below, because the
# mark has to stay the last thing on the screen and `32` finds it by scrolling
# to the bottom. So this shot is `32`'s neighbour rather than its replacement:
# same region, list layout, default text size.
shoot 47-playlists-withheld -demo -screen playlists -layout list -scrolled 99999

# ─── Reduce Motion ───────────────────────────────────────────────────────────
# The shimmer's accessibility branch, and the only shot in the set that proves a
# Reduce Motion path at all.
#
# It needs an argument because the simulator cannot be asked: writing
# `ReduceMotionEnabled` into `com.apple.Accessibility` does set the preference -
# `defaults read` returns 1 - but the accessibility daemon never reloads it, so
# `UIAccessibility` keeps reporting false. Measured before `-reduceMotion`
# existed: two frames a second apart still differed and a placeholder cover still
# swept a 30-step range.
#
# **What to check is that the placeholders are flat, not that they are still.**
# ADR-0020's claim is specific - the surface holds at its *resting* value rather
# than freezing wherever the band happened to be - and those two outcomes are
# both motionless. A tile with a bright diagonal region frozen across it is the
# failure; an even tile a shade darker than the field is the pass. Measured on
# this shot: interior luminance spread 5 (dither alone) against 17 with the sweep
# running.
shoot 48-reduce-motion -demo -screen playlists -layout grid2 -stallLibrary 30 -reduceMotion

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

# The swap. Everything this run produced replaces everything that was there.
rm -rf "$OUT"
mkdir -p "$OUT"
mv "$STAGE"/*.png "$OUT/"

echo "==> Wrote $(ls -1 "$OUT" | wc -l | tr -d ' ') screenshots to $OUT"
ls -1 "$OUT"
