#!/bin/bash
set -euo pipefail

APP_NAME="OneCC"
BUNDLE_ID="com.onecc.app"
VERSION="0.2.0"
DIST_DIR="dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

echo "Building $APP_NAME v$VERSION..."

# Build release binary
swift build -c release

# Create .app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp .build/release/OneCC "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy resources from the Swift Package bundle
BUNDLE_PATH=$(find .build/release -name "OneCC_OCC.bundle" -type d 2>/dev/null | head -1)
if [ -n "$BUNDLE_PATH" ]; then
    cp -R "$BUNDLE_PATH"/* "$APP_DIR/Contents/Resources/" 2>/dev/null || true
fi

# Copy app icon
if [ -f "OCC/Resources/AppIcon.icns" ]; then
    cp "OCC/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>OneCC</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsUsageDescription</key>
    <string>OneCC checks your calendar to provide meeting-related notifications.</string>
</dict>
</plist>
PLIST

# Ad-hoc codesign so macOS doesn't flag as "damaged"
codesign --force --deep --sign - "$APP_DIR"
# Strip quarantine attribute
xattr -cr "$APP_DIR"

echo ""
echo "Built: $APP_DIR"
echo ""
echo "To use:"
echo "  open $APP_DIR"
echo ""
echo "To share:"
echo "  zip -r dist/OneCC.zip $APP_DIR"
echo "  # Send OneCC.zip to your friend — they unzip and drag to Applications"
