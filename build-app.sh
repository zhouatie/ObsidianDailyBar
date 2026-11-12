#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Building ObsidianDailyBar (Release)..."
swift build -c release

BIN_PATH=".build/release/ObsidianDailyBar"
APP_BUNDLE="ObsidianDailyBar.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "==> Packaging into $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/ObsidianDailyBar"
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "==> Code signing ad-hoc..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Build successfully completed!"
echo "You can launch the app with: open $APP_BUNDLE"
