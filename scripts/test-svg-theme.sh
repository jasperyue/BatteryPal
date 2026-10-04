#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/SVGTests.app"
mkdir -p "$APP/Contents/MacOS" "$ROOT/.build/module-cache"
cp "$ROOT/dist/Battery Pie.app/Contents/Info.plist" "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -R "$ROOT/Resources/Themes" "$APP/Contents/Resources/"
cp -R "$ROOT/Resources/"*.lproj "$APP/Contents/Resources/"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macosx13.0" \
  -module-cache-path "$ROOT/.build/module-cache" -framework AppKit -framework IOKit \
  "$ROOT/Sources/BatteryState.swift" "$ROOT/Sources/Localization.swift" "$ROOT/Sources/Themes/"*.swift \
  "$ROOT/scripts/TestSVGTheme.swift" -o "$APP/Contents/MacOS/BatteryPie"
"$APP/Contents/MacOS/BatteryPie"
