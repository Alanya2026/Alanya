#!/usr/bin/env bash
# Fabrique les paquets Linux de l'application de bureau à partir du build
# release (flutter build linux --release, déjà fait) :
#   dist/alanya-coffre_<version>_amd64.deb   (Ubuntu, Debian, Mint)
#   dist/AlanyaCoffre-<version>.AppImage     (autres distributions ; seulement
#                                             si APPIMAGETOOL désigne l'outil)
#
# Usage : linux/packaging/build_packages.sh 1.0.0   (depuis desktop/)
# Conception : backend docs/conception/coffre-bureau.html, section 09.
set -euo pipefail

VERSION="${1:?version attendue, par ex. 1.0.0}"
ICI="$(cd "$(dirname "$0")" && pwd)"
DESKTOP="$(cd "$ICI/../.." && pwd)"
BUNDLE="$DESKTOP/build/linux/x64/release/bundle"
DIST="$DESKTOP/dist"
TRAVAIL="$(mktemp -d)"
trap 'rm -rf "$TRAVAIL"' EXIT

[ -x "$BUNDLE/alanya_coffre" ] || { echo "Pas de build : lancez d'abord flutter build linux --release" >&2; exit 1; }
mkdir -p "$DIST"

# ── .deb ─────────────────────────────────────────────────────────────────
RACINE="$TRAVAIL/deb"
mkdir -p "$RACINE/DEBIAN" "$RACINE/opt/alanya-coffre" "$RACINE/usr/bin" \
  "$RACINE/usr/share/applications" "$RACINE/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE/." "$RACINE/opt/alanya-coffre/"
ln -s /opt/alanya-coffre/alanya_coffre "$RACINE/usr/bin/alanya-coffre"
cp "$ICI/alanya-coffre.desktop" "$RACINE/usr/share/applications/"
cp "$ICI/alanya-coffre.png" "$RACINE/usr/share/icons/hicolor/512x512/apps/"
TAILLE_KO=$(du -sk "$RACINE" | cut -f1)
cat > "$RACINE/DEBIAN/control" <<CONTROL
Package: alanya-coffre
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Installed-Size: $TAILLE_KO
Depends: libgtk-3-0t64 | libgtk-3-0, libsecret-1-0, libc6, libstdc++6
Maintainer: Alanya <alanyapro64@gmail.com>
Homepage: https://www.alanya237.com/coffre
Description: Alanya Coffre-fort
 Le coffre-fort Alanya sur l'ordinateur : parcourir, regarder, ajouter,
 télécharger et ranger ses fichiers, et sauvegarder des dossiers du PC.
 Connexion par QR code avec l'application Alanya du téléphone.
CONTROL
# Les droits attendus par dpkg, quel que soit le umask de la machine.
find "$RACINE" -type d -exec chmod 755 {} +
find "$RACINE/opt" -type f -exec chmod 644 {} +
chmod 755 "$RACINE/opt/alanya-coffre/alanya_coffre"
find "$RACINE/opt/alanya-coffre/lib" -name '*.so' -exec chmod 755 {} +
chmod 644 "$RACINE/DEBIAN/control" "$RACINE/usr/share/applications/alanya-coffre.desktop" \
  "$RACINE/usr/share/icons/hicolor/512x512/apps/alanya-coffre.png"
DEB="$DIST/alanya-coffre_${VERSION}_amd64.deb"
dpkg-deb --root-owner-group --build "$RACINE" "$DEB" >/dev/null
echo "$DEB"

# ── AppImage ─────────────────────────────────────────────────────────────
if [ -n "${APPIMAGETOOL:-}" ]; then
  APPDIR="$TRAVAIL/AlanyaCoffre.AppDir"
  mkdir -p "$APPDIR/usr/bin"
  cp -a "$BUNDLE/." "$APPDIR/usr/bin/"
  cp "$ICI/alanya-coffre.desktop" "$APPDIR/"
  cp "$ICI/alanya-coffre.png" "$APPDIR/alanya-coffre.png"
  cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
ICI="$(dirname "$(readlink -f "$0")")"
exec "$ICI/usr/bin/alanya_coffre" "$@"
APPRUN
  chmod 755 "$APPDIR/AppRun"
  # Exec du .desktop : le nom du lanceur dans l'AppImage.
  sed -i 's/^Exec=.*/Exec=AppRun/' "$APPDIR/alanya-coffre.desktop"
  IMAGE="$DIST/AlanyaCoffre-${VERSION}.AppImage"
  ARCH=x86_64 "$APPIMAGETOOL" --no-appstream "$APPDIR" "$IMAGE" >/dev/null
  echo "$IMAGE"
fi
