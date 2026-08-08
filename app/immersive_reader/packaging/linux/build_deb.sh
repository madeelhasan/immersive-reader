#!/usr/bin/env bash
# Builds a .deb package for Lesefluss. Package/binary names stay
# immersive-reader/immersive_reader deliberately (internal identifiers,
# not what users see - the .desktop entry's Name=Lesefluss is what
# actually shows in an app launcher/menu).
#
# MUST be run on a real Linux machine (or Linux CI runner) with Flutter's
# Linux desktop toolchain installed - `flutter build linux` links against
# the host's GTK3/glib dev libraries, which don't exist on Windows/macOS.
# This script cannot be exercised from the Windows dev environment this
# project has otherwise been built in; it's written and reviewed, not yet
# build-tested end-to-end. Run it once on Linux and fix forward from
# whatever `flutter build linux`/`dpkg-deb` actually complain about.
#
# Usage: packaging/linux/build_deb.sh
# Output: packaging/linux/dist/immersive-reader_<version>_amd64.deb
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."  # -> app/immersive_reader/

VERSION=$(grep '^version:' pubspec.yaml | sed -E 's/version:\s*([0-9.]+).*/\1/')
ARCH=amd64
PKG_NAME=immersive-reader
STAGING="packaging/linux/dist/${PKG_NAME}_${VERSION}_${ARCH}"
OUT_DEB="packaging/linux/dist/${PKG_NAME}_${VERSION}_${ARCH}.deb"

command -v flutter >/dev/null || { echo "flutter not on PATH" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo "dpkg-deb not found - install the 'dpkg' package" >&2; exit 1; }

echo "==> flutter build linux --release"
flutter build linux --release

rm -rf "$STAGING"
mkdir -p \
  "$STAGING/DEBIAN" \
  "$STAGING/usr/lib/$PKG_NAME" \
  "$STAGING/usr/bin" \
  "$STAGING/usr/share/applications" \
  "$STAGING/usr/share/icons/hicolor/256x256/apps"

echo "==> staging bundle"
cp -r build/linux/x64/release/bundle/. "$STAGING/usr/lib/$PKG_NAME/"

# Thin launcher script rather than a symlink, so the working directory the
# bundle expects (next to its data/ and lib/ dirs) is always correct
# regardless of where the user invokes `immersive-reader` from.
cat > "$STAGING/usr/bin/$PKG_NAME" <<EOF
#!/usr/bin/env bash
exec /usr/lib/$PKG_NAME/immersive_reader "\$@"
EOF
chmod 755 "$STAGING/usr/bin/$PKG_NAME"

cp packaging/linux/immersive-reader.desktop "$STAGING/usr/share/applications/"
cp packaging/windows/app_icon.png "$STAGING/usr/share/icons/hicolor/256x256/apps/immersive-reader.png"

INSTALLED_SIZE_KB=$(du -sk "$STAGING/usr" | cut -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@INSTALLED_SIZE@/$INSTALLED_SIZE_KB/" \
  packaging/linux/control.template > "$STAGING/DEBIAN/control"

echo "==> dpkg-deb --build"
dpkg-deb --build --root-owner-group "$STAGING" "$OUT_DEB"

echo "==> built $OUT_DEB"
