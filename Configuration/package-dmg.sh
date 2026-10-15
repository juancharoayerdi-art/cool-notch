#!/bin/bash
# Builds a universal (Apple silicon + Intel) Cool Notch and packages it as dist/Cool-Notch.dmg
# with an Applications shortcut and Spanish install notes, ready to share.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Cool Notch"
DIST="$ROOT/dist"
STAGE="$DIST/stage"

xcodebuild -project "$ROOT/boringNotch.xcodeproj" -scheme boringNotch -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedDataUniversal" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM="" ENABLE_HARDENED_RUNTIME=NO \
  build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"

APP="$ROOT/build/DerivedDataUniversal/Build/Products/Release/$APP_NAME.app"
SIGN_ID="$(security find-identity -p codesigning | awk '/"Cool Notch Local"/ {print $2; exit}')"
if [ -n "$SIGN_ID" ]; then
  codesign --force --deep --preserve-metadata=entitlements,flags --sign "$SIGN_ID" "$APP"
fi

rm -rf "$STAGE" "$DIST/Cool-Notch.dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Aplicaciones"
cp "$ROOT/Configuration/LEEME.txt" "$STAGE/LEEME.txt"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DIST/Cool-Notch.dmg" >/dev/null
rm -rf "$STAGE"
echo "Created $DIST/Cool-Notch.dmg ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"
