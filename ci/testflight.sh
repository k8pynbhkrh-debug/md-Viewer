#!/bin/bash
#
# Baut ein Release-Archive von "md Viewer" und lädt es zu TestFlight hoch.
#
# Voraussetzung: ein App-Store-Connect-API-Key (Rolle "App Manager" oder höher).
# Aufruf:
#
#   ci/testflight.sh \
#     --key   /Pfad/zu/AuthKey_XXXXXXXXXX.p8 \
#     --key-id XXXXXXXXXX \
#     --issuer 12345678-1234-1234-1234-1234567890ab
#
# Der Key wird nach ~/.appstoreconnect/private_keys/ kopiert (dort erwartet ihn
# xcodebuild/altool). Nichts davon wird committet.

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

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_DIR="$REPO_ROOT/md Viewer"
BUILD_DIR="$REPO_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/md Viewer.xcarchive"
EXPORT_DIR="$BUILD_DIR/testflight-export"
KEY_DEST_DIR="$HOME/.appstoreconnect/private_keys"

mkdir -p "$KEY_DEST_DIR"
cp "$KEY_PATH" "$KEY_DEST_DIR/AuthKey_${KEY_ID}.p8"

echo "▸ Archive …"
rm -rf "$ARCHIVE_PATH"
xcodebuild \
  -project "$XCODE_DIR/md Viewer.xcodeproj" \
  -scheme "md Viewer" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_DEST_DIR/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  archive

echo "▸ Export + Upload zu App Store Connect …"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$XCODE_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_DEST_DIR/AuthKey_${KEY_ID}.p8" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

echo "✓ Upload angestoßen. Verarbeitung in App Store Connect → TestFlight dauert ein paar Minuten."
