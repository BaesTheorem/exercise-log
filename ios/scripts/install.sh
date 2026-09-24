#!/usr/bin/env bash
# Build signed, then install and launch on a connected iPhone.
# Usage: scripts/install.sh [device-udid]
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

UDID="${1:-}"
if [ -z "$UDID" ]; then
  # Match the identifier by shape. Column position is not reliable here:
  # the device name column contains spaces ("iPhone 16 Pro").
  # `|| true` because under `set -euo pipefail` a no-match grep would kill
  # the script with no output at all; the empty-UDID check below is the
  # error path and actually explains the problem.
  # "connected" is a live cable session; "available (paired)" still reaches
  # the device over the network tunnel.
  UDID=$(xcrun devicectl list devices 2>/dev/null | grep -iE 'connected|available' \
    | grep -oiE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1 || true)
fi
if [ -z "$UDID" ]; then
  echo "No connected device found. Plug the phone in, unlock it, and trust this Mac." >&2
  exit 1
fi

scripts/build.sh --device

# devicectl resolves the bundle through a file bookmark, which fails on a
# relative path once the shell's directory has moved; hand it an absolute one.
APP="$(pwd)/build/dd/Build/Products/Release-iphoneos/ExerciseLog.app"

xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" --terminate-existing \
  com.alexhedtke.exerciselog
