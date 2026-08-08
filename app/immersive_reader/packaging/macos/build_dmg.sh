#!/usr/bin/env bash
# Builds a .dmg installer for Immersive Reader.
#
# MUST be run on a real Mac with Xcode (and its command-line tools)
# installed - `flutter build macos` shells out to `xcodebuild`, which has
# no equivalent on Windows/Linux. This script cannot be exercised from the
# Windows dev environment this project has otherwise been built in; it's
# written and reviewed, not yet build-tested end-to-end. Run it once on
# macOS and fix forward from whatever `flutter build macos`/`hdiutil`
# actually complain about.
#
# Not code-signed or notarized - an unsigned .app will be Gatekeeper-
# blocked on any Mac other than the one that built it (open via
# right-click -> Open to bypass locally). Signing/notarization needs an
# Apple Developer account and is tracked separately in TODO.md.
#
# Usage: packaging/macos/build_dmg.sh
# Output: packaging/macos/dist/ImmersiveReader-<version>.dmg
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."  # -> app/immersive_reader/

VERSION=$(grep '^version:' pubspec.yaml | sed -E 's/version:\s*([0-9.]+).*/\1/')
APP_NAME="Immersive Reader"
DIST_DIR="packaging/macos/dist"
OUT_DMG="$DIST_DIR/ImmersiveReader-${VERSION}.dmg"
STAGING="$DIST_DIR/staging"

command -v flutter >/dev/null || { echo "flutter not on PATH" >&2; exit 1; }
command -v hdiutil >/dev/null || { echo "hdiutil not found - this must run on macOS" >&2; exit 1; }

echo "==> flutter build macos --release"
flutter build macos --release

BUILT_APP="build/macos/Build/Products/Release/${APP_NAME}.app"
if [ ! -d "$BUILT_APP" ]; then
  # Fall back to whatever .app actually got produced, in case the product
  # name in the Xcode project doesn't match $APP_NAME exactly.
  BUILT_APP=$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -n1)
fi
[ -d "$BUILT_APP" ] || { echo "No .app found under build/macos/Build/Products/Release" >&2; exit 1; }

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$BUILT_APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p "$DIST_DIR"
rm -f "$OUT_DMG"

echo "==> hdiutil create"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$OUT_DMG"

rm -rf "$STAGING"
echo "==> built $OUT_DMG"
