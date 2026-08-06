#!/bin/bash
# Headless screenshots of every screen on the iOS 27 simulator.
#
# Deliberately never drives the simulator GUI — each screen is reached from a
# cold launch via the DebugLaunch arguments, then captured with `simctl io
# screenshot`. That keeps this runnable while the Mac is being used for
# something else, and keeps it reproducible.
set -euo pipefail

DEVICE="${DEVICE:-iPhone 17 Pro}"
OS="${OS:-27.0}"
BUNDLE_ID="com.fulltimestudio.sortify"
OUT="${OUT:-$(cd "$(dirname "$0")/.." && pwd)/screenshots}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$OUT"

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
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
}

shoot 01-landing        -screen landing
shoot 02-playlists      -screen playlists
shoot 03-tracks-order   -screen tracks -playlist demo-longrun
shoot 04-tracks-bpm     -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 05-tracks-asep    -screen tracks -playlist demo-mixed -arrangement artist-separation
# Shuffle is the one chip that carries a second control, so it gets its own shot.
shoot 06-tracks-shuffle -screen tracks -playlist demo-longrun -arrangement shuffle
# An Arrangement outside the pinned five: it should trail the row and be
# scrolled into view, or picking it would select a chip nobody can see.
shoot 07-tracks-offpiste -screen tracks -playlist demo-longrun -arrangement valence-descending
# Tracks the Arrangement can't place. The tempo range is chosen to leave a few
# ranked tracks on screen as well: the case worth seeing is the common one,
# where *some* tracks were placed and some weren't — the case the old
# all-or-nothing notice never fired for.
shoot 08-tracks-unrankable -screen tracks -playlist demo-mixed -arrangement bpm-ascending -filter 140-160
# Every Attribute across one track — the half of the old table the list can't
# do, and the reason ADR-0001's trade was acceptable.
shoot 09-track-detail   -screen tracks -playlist demo-longrun -sheet track -track 0
# Position 22 of demo-mixed arranged by BPM is past the ranked tracks: a track
# the feature source had nothing for. Every audio feature should read
# "Unavailable" and draw no bar, while Spotify's own values still do.
shoot 10-track-detail-missing -screen tracks -playlist demo-mixed -arrangement bpm-ascending -sheet track -track 22
shoot 11-arrangements   -screen tracks -playlist demo-longrun -sheet arrangements
shoot 12-settings       -screen settings
shoot 13-faq            -screen faq

# The list and the sheet both have to hold when the text is as large as iOS will
# make it — the old table simply clipped, which is the failure this redesign
# exists to end.
echo "==> large text (accessibility text size)"
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
shoot 14-tracks-large-text -screen tracks -playlist demo-longrun -arrangement bpm-descending
shoot 15-track-detail-large-text -screen tracks -playlist demo-longrun -sheet track -track 0

# One step into the accessibility sizes rather than at the top of them. The
# sheet stacks its rows from here on, and this is the only size where the
# stacked rows are actually on screen — at the maximum the identity above them
# fills it, and the harness can't scroll.
xcrun simctl ui "$UDID" content_size accessibility-large
shoot 16-track-detail-stacked -screen tracks -playlist demo-longrun -sheet track -track 0
xcrun simctl ui "$UDID" content_size medium

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "==> Wrote screenshots to $OUT"
ls -1 "$OUT"
