#!/bin/bash
# Builds Cool Notch (Release) and installs it into /Applications.
# Hardened runtime is disabled for local builds: library validation would otherwise
# reject the embedded frameworks at launch.
# If a local "Cool Notch Local" code-signing certificate exists in the keychain, the
# app is re-signed with it so macOS privacy permissions (Accessibility) survive rebuilds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Cool Notch"
BUNDLE_ID="com.juanayerdi.coolnotch"

xcodebuild -project "$ROOT/boringNotch.xcodeproj" -scheme boringNotch -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" ENABLE_HARDENED_RUNTIME=NO \
  build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

APP="$ROOT/build/DerivedData/Build/Products/Release/$APP_NAME.app"
SIGN_ID="$(security find-identity -p codesigning | awk '/"Cool Notch Local"/ {print $2; exit}')"
if [ -n "$SIGN_ID" ]; then
  codesign --force --deep --preserve-metadata=entitlements,flags --sign "$SIGN_ID" "$APP"
  echo "Signed with Cool Notch Local ($SIGN_ID)"
else
  echo "Cool Notch Local certificate not found; keeping ad-hoc signature"
fi

osascript -e "quit app id \"$BUNDLE_ID\"" 2>/dev/null || true
sleep 1
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP" /Applications/
open "/Applications/$APP_NAME.app"
echo "Installed /Applications/$APP_NAME.app"
