#!/bin/bash
# Headless screenshots of every screen, on the iOS 27 simulator.
#
# Deliberately never drives the simulator GUI. Every screen is reached from a
# *cold launch* through the `DebugLaunch` arguments and captured with `simctl io
# screenshot`, which is what keeps this runnable while the Mac is being used for
# something else, and what keeps it reproducible: the demo catalogue is
# generated from a fixed seed, so the same run produces the same pixels.
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
BUNDLE_ID="com.fulltimestudio.sortify"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$ROOT/screenshots}"

# Staged, then swapped in. A screen that no longer exists must not leave its
# screenshot behind pretending it does - replacing the whole directory at the
# end rather than writing over it makes that structural instead of a chore.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> Building"
xcodebuild -project "$ROOT/Sortify.xcodeproj" -scheme Sortify \
  -destination "platform=iOS Simulator,name=$DEVICE,OS=$OS" \
  -configuration Debug -derivedDataPath "$ROOT/.build" build >/dev/null

APP="$ROOT/.build/Build/Products/Debug-iphonesimulator/Sortify.app"

UDID=$(xcrun simctl list devices available -j \
  | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next(x['udid'] for k,v in d.items() if 'iOS-${OS//./-}' in k for x in v if x['name']=='$DEVICE'))")

echo "==> Booting $DEVICE ($UDID)"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null

xcrun simctl install "$UDID" "$APP"

shoot() {
  local name="$1"; shift
  echo "==> $name"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" >/dev/null
  sleep "${SETTLE:-4}"
  xcrun simctl io "$UDID" screenshot --type=png "$STAGE/$name.png" >/dev/null
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

# The library has three layouts and only its default is shot above. The two-up
# is the one worth a second look: it is the density the first redesign measured
# and rejected, kept as an option.
shoot 14-playlists-two-up  -demo -screen playlists -layout grid2

shoot 15-settings          -demo -screen settings
shoot 16-faq               -demo -screen faq

# ─── Largest text size ───────────────────────────────────────────────────────
# The old table simply clipped here, which is the failure the redesign exists to
# end. Nothing may truncate; everything may wrap.
echo "==> largest text size"
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
shoot 17-tracks-large-text       -demo -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 18-track-detail-large-text -demo -screen tracks -playlist demo-longrun -sheet track -track 0
shoot 19-playlists-large-text    -demo -screen playlists

# ─── One step into the accessibility sizes ───────────────────────────────────
# Both screens take their stacked layout from here on, and this is the smallest
# size at which the stacked content is actually on screen: at the maximum the
# header fills it, and the harness can't scroll.
echo "==> accessibility-large"
xcrun simctl ui "$UDID" content_size accessibility-large
shoot 20-track-detail-stacked -demo -screen tracks -playlist demo-longrun -sheet track -track 0
shoot 21-playlists-stacked    -demo -screen playlists
xcrun simctl ui "$UDID" content_size medium

# ─── Dark ────────────────────────────────────────────────────────────────────
# First-class, not an afterthought: the accent has its own value there
# (ADR-0006) and the bars are drawn against a different surface.
echo "==> dark appearance"
xcrun simctl ui "$UDID" appearance dark
shoot 22-dark-playlists    -demo -screen playlists
shoot 23-dark-tracks       -demo -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 24-dark-track-detail -demo -screen tracks -playlist demo-longrun -sheet track -track 0
shoot 25-dark-connect      -demo -screen connect -connectStep createApp
xcrun simctl ui "$UDID" appearance light

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
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
shoot 29-playlists-scrolled -demo -screen playlists -scrolled 420
xcrun simctl ui "$UDID" content_size medium

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true

# The swap. Everything this run produced replaces everything that was there.
rm -rf "$OUT"
mkdir -p "$OUT"
mv "$STAGE"/*.png "$OUT/"

echo "==> Wrote $(ls -1 "$OUT" | wc -l | tr -d ' ') screenshots to $OUT"
ls -1 "$OUT"
