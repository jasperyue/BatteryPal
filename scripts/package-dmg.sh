#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/build.sh"
APP="$ROOT/dist/Battery Pie.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(uname -m)
DMG="$ROOT/dist/BatteryPie-$VERSION-$ARCH.dmg"
STAGE=$(mktemp -d "$ROOT/.build/dmg-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Battery Pie.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/docs/INSTALL.txt" "$STAGE/READ ME.txt"
hdiutil create -volname "Battery Pie" -srcfolder "$STAGE" -format UDZO -fs HFS+ -ov "$DMG"
hdiutil verify "$DMG"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
printf 'Packaged: %s\n' "$DMG"
