#!/bin/bash
# ============================================
# GlassOS Build Script
# Double-click this file to build GlassOS.app
# Requires: macOS 13+ and Xcode Command Line Tools
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="GlassOS"
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
UPDATE_MODE=false

if [ "$1" = "--update" ]; then
    UPDATE_MODE=true
fi

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║         GlassOS Build System          ║"
echo "║         Version: $VERSION               ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Check for Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    echo "⚠️  Xcode Command Line Tools not found."
    echo "   Installing... (this may take a few minutes)"
    xcode-select --install
    echo ""
    echo "Please run this script again after installation completes."
    exit 1
fi

echo "→ Building $APP_NAME v$VERSION..."
echo ""

# Build with Swift Package Manager
swift build -c release 2>&1 | while IFS= read -r line; do
    if [[ "$line" == *"error:"* ]]; then
        echo "  ✗ $line"
    elif [[ "$line" == *"Build complete!"* ]]; then
        echo "  ✓ $line"
    elif [[ "$line" == *"Compiling"* ]]; then
        echo "  ◦ $line"
    fi
done

SWIFT_EXIT=${PIPESTATUS[0]}
if [ $SWIFT_EXIT -ne 0 ]; then
    echo ""
    echo "✗ Build failed. Check errors above."
    echo "  Make sure you have Xcode Command Line Tools installed:"
    echo "  xcode-select --install"
    if [ "$UPDATE_MODE" = false ]; then
        echo ""
        read -n 1 -s -r -p "Press any key to exit..."
    fi
    exit 1
fi

echo ""
echo "→ Creating app bundle..."

# Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Create Info.plist with current version
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.glassos.app</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

# Copy VERSION file into Resources
cp VERSION "$APP_BUNDLE/Contents/Resources/VERSION"

echo "  ✓ App bundle created: $APP_BUNDLE"

# If updating, replace the running app
if [ "$UPDATE_MODE" = true ]; then
    RUNNING_APP=$(osascript -e 'tell application "System Events" to get POSIX path of (file of process "GlassOS")' 2>/dev/null || echo "")
    if [ -n "$RUNNING_APP" ] && [ -d "$RUNNING_APP" ]; then
        echo "→ Replacing running app at: $RUNNING_APP"
        rm -rf "$RUNNING_APP"
        cp -R "$APP_BUNDLE" "$RUNNING_APP"
        echo "  ✓ Update installed. Restart GlassOS to apply."
    fi
    exit 0
fi

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║          Build Complete! ✓            ║"
echo "╚═══════════════════════════════════════╝"
echo ""
echo "  App: $APP_BUNDLE"
echo "  Version: $VERSION"
echo ""

# Ask to launch
read -n 1 -s -r -p "Press any key to launch GlassOS..."
echo ""
open "$APP_BUNDLE"
