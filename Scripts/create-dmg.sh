#!/bin/bash
set -euo pipefail

APP_NAME="ClaudeStation"
VERSION="${1:-1.0.0}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR=".build/release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg-staging"

# Build first if needed
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "Building app first..."
    ./Scripts/bundle.sh
fi

echo "Creating DMG..."

# Clean staging
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app
cp -r "$BUNDLE_DIR" "$DMG_DIR/"

# Create symlink to /Applications
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
rm -f "$BUILD_DIR/$DMG_NAME"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

# Clean staging
rm -rf "$DMG_DIR"

echo ""
echo "DMG created: $BUILD_DIR/$DMG_NAME"
echo "Size: $(du -h "$BUILD_DIR/$DMG_NAME" | cut -f1)"
