#!/bin/bash
# Publishes a Cool Notch release that existing installs pick up automatically (Sparkle).
#
#   Configuration/release.sh <version> <build> <notes.md>
#   e.g. Configuration/release.sh 1.3 1300 notes.md
#
# Steps: bump the version, build the universal DMG (package-dmg.sh), sign it with the
# "cool-notch" Sparkle EdDSA key from the keychain, write dist/appcast.xml, commit + push,
# and create GitHub release v<version> with the DMG and appcast.xml. Apps check
# https://github.com/juancharoayerdi-art/cool-notch/releases/latest/download/appcast.xml
# The build number must always be higher than the previous release's.
set -euo pipefail

VERSION="${1:?version, e.g. 1.3}"
BUILD="${2:?build number, e.g. 1300}"
NOTES="${3:?path to release notes (markdown)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="juancharoayerdi-art/cool-notch"
PUBLISH_ACCOUNT="juancharoayerdi-art"
DEFAULT_ACCOUNT="juanayerdi-num"
SPARKLE_BIN="$(dirname "$(find "$ROOT/build" -path '*artifacts/sparkle/Sparkle/bin/sign_update' -print -quit)")"

[ -x "$SPARKLE_BIN/sign_update" ] || { echo "Sparkle tools not found; build the app once first"; exit 1; }

# 1. Version
sed -i '' -E \
  -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = $VERSION;/" \
  -e "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = $BUILD;/" \
  "$ROOT/boringNotch.xcodeproj/project.pbxproj"

# 2. Universal DMG
"$ROOT/Configuration/package-dmg.sh"
DMG="$ROOT/dist/Cool-Notch.dmg"

# 3. Sparkle signature + appcast
SIG_ATTRS="$("$SPARKLE_BIN/sign_update" --account cool-notch "$DMG")"
NOTES_HTML="$(python3 -I - "$NOTES" <<'PY'
import html, sys
out, in_list = [], False
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    line = line.strip()
    if line.startswith("- "):
        if not in_list: out.append("<ul>"); in_list = True
        out.append("<li>" + html.escape(line[2:]).replace("**", "") + "</li>")
        continue
    if in_list: out.append("</ul>"); in_list = False
    if line: out.append("<p>" + html.escape(line).replace("**", "") + "</p>")
if in_list: out.append("</ul>")
print("\n".join(out))
PY
)"
cat > "$ROOT/dist/appcast.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Cool Notch</title>
    <item>
      <title>Cool Notch $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
$NOTES_HTML
      ]]></description>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/Cool-Notch.dmg" type="application/octet-stream" $SIG_ATTRS />
    </item>
  </channel>
</rss>
XML

# 4. Commit, push and publish with the personal account, then restore the default account
git -C "$ROOT" commit -qam "Version $VERSION (build $BUILD)" || true
gh auth switch -h github.com -u "$PUBLISH_ACCOUNT" >/dev/null
trap 'gh auth switch -h github.com -u "$DEFAULT_ACCOUNT" >/dev/null 2>&1 || true' EXIT
git -C "$ROOT" -c credential.helper= -c credential.helper='!gh auth git-credential' push -q origin main
gh release create "v$VERSION" "$DMG" "$ROOT/dist/appcast.xml" --repo "$REPO" \
  --title "Cool Notch $VERSION" --notes-file "$NOTES"
echo "Published v$VERSION"
