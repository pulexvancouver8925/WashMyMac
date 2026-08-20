#!/bin/bash
# Builds WashMyMac.app. With --install it also drops the app into /Applications.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="WashMyMac"
BUILD_DIR=".build/bundle"
APP="$BUILD_DIR/$APP_NAME.app"

echo "▸ Compiling (universal: arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64

BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

echo "▸ Assembling the bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
for lproj in Resources/*.lproj; do
  cp -R "$lproj" "$APP/Contents/Resources/"
done
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ Icon"
swift tools/make_icon.swift "$APP/Contents/Resources/AppIcon.icns" >/dev/null

echo "▸ Signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "▸ Installing into /Applications"
  # Remove the old copy so no process with the old signature survives.
  pkill -x "$APP_NAME" 2>/dev/null || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
  echo "✓ /Applications/$APP_NAME.app"
else
  echo "✓ $(pwd)/$APP"
fi
