#!/bin/bash
set -euo pipefail

# Build a release .app bundle and .dmg for Pocket Gris
# Usage: ./scripts/build-release.sh [--skip-tests]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Pocket Gris"
BUNDLE_NAME="Pocket Gris.app"
VERSION=$(grep -o '"[0-9]*\.[0-9]*\.[0-9]*"' "$PROJECT_DIR/Sources/PocketGrisCore/PocketGrisCore.swift" | tr -d '"')
DMG_NAME="PocketGris-${VERSION}.dmg"

BUILD_DIR="$PROJECT_DIR/.build/release-bundle"
APP_DIR="$BUILD_DIR/$BUNDLE_NAME"
DMG_DIR="$BUILD_DIR/dmg-staging"

echo "=== Pocket Gris Release Build ==="
echo "Version: $VERSION"
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Run tests (unless skipped)
if [[ "${1:-}" != "--skip-tests" ]]; then
    echo "--- Running tests ---"
    cd "$PROJECT_DIR"
    swift test --quiet
    echo "Tests passed."
    echo ""
fi

# Build release binary
echo "--- Building release binary ---"
cd "$PROJECT_DIR"
swift build -c release --product PocketGrisApp 2>&1 | tail -1

BINARY="$PROJECT_DIR/.build/release/PocketGrisApp"
if [[ ! -f "$BINARY" ]]; then
    echo "Error: Release binary not found at $BINARY"
    exit 1
fi
echo "Binary size: $(du -h "$BINARY" | cut -f1)"
echo ""

# Assemble .app bundle
echo "--- Assembling .app bundle ---"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
cp "$BINARY" "$APP_DIR/Contents/MacOS/PocketGrisApp"

# Copy Info.plist
cp "$PROJECT_DIR/Sources/PocketGrisApp/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy sprites (exclude _archive)
echo "Copying sprites..."
rsync -a --exclude='_archive' "$PROJECT_DIR/Resources/Sprites/" "$APP_DIR/Contents/Resources/Sprites/"

# Create PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

echo "Bundle created at: $APP_DIR"
echo "Bundle size: $(du -sh "$APP_DIR" | cut -f1)"
echo ""

# Ad-hoc code sign
echo "--- Code signing (ad-hoc) ---"
codesign --force --deep --sign - "$APP_DIR"
echo "Signed."
echo ""

# Verify the bundle runs
echo "--- Verifying bundle ---"
codesign --verify "$APP_DIR" && echo "Code signature valid."
echo ""

# Create DMG
echo "--- Creating DMG ---"
mkdir -p "$DMG_DIR"
cp -R "$APP_DIR" "$DMG_DIR/"

# Create a symlink to /Applications for drag-install
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

echo ""
echo "=== Build complete ==="
echo "DMG: $BUILD_DIR/$DMG_NAME"
echo "Size: $(du -h "$BUILD_DIR/$DMG_NAME" | cut -f1)"
