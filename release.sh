#!/bin/bash
set -euo pipefail

export APPLE_ID=""
export APPLE_ID_PASSWORD=""

APP_NAME="razer-battery-menu-bar.app"

# Build a universal binary (Apple Silicon + Intel) in one .app.
# Both are pinned explicitly so the output never depends on the machine
# doing the building.
xcodebuild -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

# Xcode already ad-hoc signs the app with the entitlements and the hardened
# runtime (CODE_SIGN_IDENTITY[sdk=macosx*] = "-"), so no re-signing here:
# `codesign -s - --deep --force` without --entitlements/-o runtime strips both.

mkdir -p out
rm -rf "./out/$APP_NAME"
mv "build/Release/$APP_NAME" "./out/$APP_NAME"

# Fail loudly rather than shipping a single-architecture build.
ARCHS_BUILT=$(lipo -archs "./out/$APP_NAME/Contents/MacOS/razer-battery-menu-bar")
for arch in arm64 x86_64; do
  if [[ " $ARCHS_BUILT " != *" $arch "* ]]; then
    echo "ERROR: $APP_NAME is missing the $arch slice (got: $ARCHS_BUILT)" >&2
    exit 1
  fi
done
echo "✓ universal build: $ARCHS_BUILT"

unset APPLE_ID
unset APPLE_ID_PASSWORD

rm -rf build
