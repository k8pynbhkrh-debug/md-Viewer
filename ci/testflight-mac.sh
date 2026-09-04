#!/bin/bash
#
# Baut ein Release-Archive der Mac-Catalyst-Variante von "md Viewer" und lädt es
# zu App Store Connect / TestFlight (macOS) hoch. Schwesterskript zu
# ci/testflight.sh (iOS) — die Mac-Version wird separat geprüft, kann aber
# parallel zur iOS-Einreichung laufen (Universal Purchase, gleiches Listing).
#
# WICHTIG — eigener Versions-Strang für den Mac:
# Die Xcode-Projekteinstellungen (MARKETING_VERSION / CURRENT_PROJECT_VERSION)
# gehören dem iOS-Strang (aktuell 1.2 / 10). Der Mac App Store hat seinen eigenen
# Strang und startet mit Marketing-Version 1.0. Dieses Skript überschreibt daher
# beim Archivieren MAC_MARKETING_VERSION / MAC_BUILD — nicht die pbxproj ändern.
#
# ACHTUNG Build-Nummer: App Store Connect verlangt, dass CURRENT_PROJECT_VERSION
# pro Plattform monoton wächst, UNABHÄNGIG von der Marketing-Version. Für den Mac
# wurden vorab Test-Builds 11/12/13 hochgeladen, daher startet MAC_BUILD bei 14
# (ein „1.0 (1)" wurde von ASC still verworfen, weil 1 < 13). Ein niedriger Build
# erscheint einfach nie in ASC — kein Fehler beim Upload.
# Nächstes Mac-Update: MAC_MARKETING_VERSION=1.1 MAC_BUILD=15 ci/testflight-mac.sh …
#
# Zusätzliche Voraussetzungen gegenüber ci/testflight.sh (einmalig, alle per
# App-Store-Connect-API am 2026-09-04 eingerichtet):
#  1. "Mac Installer Distribution"-Zertifikat im Login-Schlüsselbund
#     (`security find-identity -v` zeigt "3rd Party Mac Developer Installer …").
#  2. "Mac Catalyst App Store"-Provisioning-Profile "md Viewer Mac App Store" und
#     "md Viewer ShareExtension Mac App Store" in
#     ~/Library/MobileDevice/Provisioning Profiles/ (siehe ExportOptions-mac.plist).
#  3. Die App ist sandboxed (md Viewer.entitlements / ShareExtension.entitlements)
#     — Pflicht für den Mac App Store.
#  4. ExportOptions-mac.plist pinnt beide Zertifikate per SHA-1 (Xcode-Bug-Umgehung,
#     siehe Kommentar dort).
#
# Aufruf identisch zu ci/testflight.sh:
#
#   ci/testflight-mac.sh \
#     --key   /Pfad/zu/AuthKey_XXXXXXXXXX.p8 \
#     --key-id XXXXXXXXXX \
#     --issuer 12345678-1234-1234-1234-1234567890ab

set -euo pipefail

KEY_PATH="" ; KEY_ID="" ; ISSUER_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --key)    KEY_PATH="$2" ; shift 2 ;;
    --key-id) KEY_ID="$2"   ; shift 2 ;;
    --issuer) ISSUER_ID="$2"; shift 2 ;;
    *) echo "Unbekanntes Argument: $1" ; exit 2 ;;
  esac
done

if [ -z "$KEY_PATH" ] || [ -z "$KEY_ID" ] || [ -z "$ISSUER_ID" ]; then
  echo "Fehlt: --key / --key-id / --issuer" ; exit 2
fi

MAC_MARKETING_VERSION="${MAC_MARKETING_VERSION:-1.0}"
MAC_BUILD="${MAC_BUILD:-14}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_DIR="$REPO_ROOT/md Viewer"
BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/md Viewer (Mac).xcarchive"
EXPORT_DIR="$BUILD_DIR/testflight-export-mac"
KEY_DEST_DIR="$HOME/.appstoreconnect/private_keys"

mkdir -p "$KEY_DEST_DIR"
KEY_DEST="$KEY_DEST_DIR/AuthKey_${KEY_ID}.p8"
if [ ! "$KEY_PATH" -ef "$KEY_DEST" ]; then
  cp "$KEY_PATH" "$KEY_DEST"
fi

echo "▸ Archive (Mac Catalyst) — Version $MAC_MARKETING_VERSION ($MAC_BUILD) …"
rm -rf "$ARCHIVE_PATH"
xcodebuild \
  -project "$XCODE_DIR/md Viewer.xcodeproj" \
  -scheme "md Viewer" \
  -configuration Release \
  -destination "generic/platform=macOS,variant=Mac Catalyst" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_DEST_DIR/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  MARKETING_VERSION="$MAC_MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$MAC_BUILD" \
  archive

echo "▸ Export + Upload zu App Store Connect …"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$XCODE_DIR/ExportOptions-mac.plist" \
  -exportPath "$EXPORT_DIR" \
  -authenticationKeyPath "$KEY_DEST_DIR/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

echo "✓ Upload angestoßen. Verarbeitung in App Store Connect → TestFlight (macOS) dauert ein paar Minuten."
