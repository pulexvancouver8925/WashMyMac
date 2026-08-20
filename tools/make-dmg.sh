#!/bin/bash
# Packs the built app into dist/WashMyMac-<version>.dmg with an /Applications
# drop target, so the app never ends up being run from ~/Downloads.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="WashMyMac"
APP=".build/bundle/$APP_NAME.app"

[[ -d "$APP" ]] || { echo "no $APP — run ./build.sh first" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE=$(mktemp -d)
DMG="dist/$APP_NAME-v$VERSION.dmg"

mkdir -p dist
rm -f "$DMG"

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -quiet \
  "$DMG"

rm -rf "$STAGE"
echo "✓ $(pwd)/$DMG"
