#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Battery Pie.app"
VERSION=$(cat "$ROOT/VERSION")
BUILD_NUMBER=$(cat "$ROOT/BUILD_NUMBER")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid VERSION' >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo 'Invalid BUILD_NUMBER' >&2; exit 1; }
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/.build/module-cache"
xcrun swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx13.0" \
  -module-cache-path "$ROOT/.build/module-cache" \
  -framework AppKit -framework IOKit -framework ServiceManagement \
  "$ROOT/Sources/"*.swift "$ROOT/Sources/Themes/"*.swift -o "$APP/Contents/MacOS/BatteryPie"
cp -R "$ROOT/Resources/"*.lproj "$APP/Contents/Resources/"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>BatteryPie</string>
<key>CFBundleIdentifier</key><string>dev.local.batterypie</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>Battery Pie</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.0.0</string>
<key>CFBundleVersion</key><string>0</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string></array>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Battery Pie contributors. MIT License.</string>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
"$APP/Contents/MacOS/BatteryPie" --self-test
"$APP/Contents/MacOS/BatteryPie" --localization-test
printf 'Built: %s\n' "$APP"
