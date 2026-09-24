#!/usr/bin/env bash
# Build the iOS app. Pass --device for a signed build, otherwise it compiles
# without signing (enough to prove the code and SDK linkage).
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# launchd runs with a bare PATH, so Homebrew tools like xcodegen are invisible
# unless we go find them.
if ! command -v xcodegen >/dev/null 2>&1; then
  for prefix in /opt/homebrew /usr/local; do
    if [ -x "$prefix/bin/xcodegen" ]; then
      PATH="$prefix/bin:$PATH"
      export PATH
      break
    fi
  done
fi

if [ ! -f Config/Signing.xcconfig ]; then
  echo "Config/Signing.xcconfig is missing. Copy the .example and set your team." >&2
  exit 1
fi

xcodegen generate

if [ "${1:-}" = "--device" ]; then
  TEAM=$(awk -F'= *' '/DEVELOPMENT_TEAM/ {print $2}' Config/Signing.xcconfig | tr -d ' ')
  xcodebuild -project ExerciseLog.xcodeproj -scheme ExerciseLog \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath build/dd -allowProvisioningUpdates \
    "DEVELOPMENT_TEAM=$TEAM" build
  echo "Built: build/dd/Build/Products/Release-iphoneos/ExerciseLog.app"
else
  xcodebuild -project ExerciseLog.xcodeproj -scheme ExerciseLog \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build
  echo "Compile check passed (unsigned)."
fi
