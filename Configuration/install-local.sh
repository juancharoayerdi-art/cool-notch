#!/bin/bash
# Builds Cool Notch (Release, ad-hoc signed) and installs it into /Applications.
# Hardened runtime is disabled for local ad-hoc builds: library validation would
# otherwise reject the embedded ad-hoc signed frameworks at launch.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Cool Notch"
BUNDLE_ID="com.juanayerdi.coolnotch"

xcodebuild -project "$ROOT/boringNotch.xcodeproj" -scheme boringNotch -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" ENABLE_HARDENED_RUNTIME=NO \
  build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

osascript -e "quit app id \"$BUNDLE_ID\"" 2>/dev/null || true
sleep 1
rm -rf "/Applications/$APP_NAME.app"
cp -R "$ROOT/build/DerivedData/Build/Products/Release/$APP_NAME.app" /Applications/
open "/Applications/$APP_NAME.app"
echo "Installed /Applications/$APP_NAME.app"
