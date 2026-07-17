#!/bin/bash
# Builds BreakPlane.app — a double-clickable, menu-bar-only macOS app.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building release binary..."
swift build -c release

APP="BreakPlane.app"
BIN="$(swift build -c release --show-bin-path)/BreakPlane"

echo "==> Assembling $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BreakPlane"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>BreakPlane</string>
    <key>CFBundleDisplayName</key>     <string>BreakPlane</string>
    <key>CFBundleIdentifier</key>      <string>com.local.breakplane</string>
    <key>CFBundleExecutable</key>      <string>BreakPlane</string>
    <key>CFBundleVersion</key>         <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
</dict>
</plist>
PLIST

# Ad-hoc code signature so Gatekeeper lets a locally-built app run.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Done: $(pwd)/$APP"
echo "    Launch it with:  open \"$(pwd)/$APP\""
echo "    Or drag it into /Applications."
