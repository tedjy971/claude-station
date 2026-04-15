#!/bin/bash
set -euo pipefail

APP_NAME="ClaudeStation"
BUILD_DIR=".build/release"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$BUNDLE_DIR/Contents/MacOS/"
cp Resources/Info.plist "$BUNDLE_DIR/Contents/"

echo "Signing..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo ""
echo "Built: $BUNDLE_DIR"
echo "Run:   open $BUNDLE_DIR"
echo ""
echo "To install permanently:"
echo "  cp -r $BUNDLE_DIR /Applications/"
