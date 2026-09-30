#!/bin/bash
# App-Store-Screenshots für iOS 1.6: Suche (alle Geräte) und Tabs (iPad).
# Ersetzt je Satz das Sprachen-Motiv (08) durch die Suche; iPad bekommt 04 mit Tab-Leiste.
# Voraussetzung: driver.sh build. Aufruf: screenshots-tabs-find.sh <udid> <de|en> <iphone|ipad> <out-dir>
set -uo pipefail
UDID="$1"; L="$2"; FORM="$3"; OUT="$4"
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$REPO/build/DerivedData-sim/Build/Products/Debug-iphonesimulator/md Viewer.app"
BID="com.eribert.md-Viewer"
DEMO="$REPO/App-Store-Screenshots/demo-dokumente/$L"
if [[ $L == de ]]; then LA=(-AppleLanguages "(de)" -AppleLocale de_DE);KB="de_DE@sw=QWERTZ-German;hw=Automatic"; TEAM="Team-Notiz.md"; MATRIX="Release-Matrix.md"; CODE="Code-Beispiele.md"
  OV=04-uebersicht; FIND=08-suchen; else LA=(-AppleLanguages "(en)" -AppleLocale en_US);KB="en_US@sw=QWERTY;hw=Automatic"; TEAM="Team-Note.md"; MATRIX="Release-Matrix.md"; CODE="Code-Examples.md"
  OV=04-overview; FIND=08-find; fi
D="${SHOT_DELAY:-5}"
mkdir -p "$OUT"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
# Software-Tastatur in der Sprache des Screenshots (sonst zeigt z. B. en eine QWERTZ mit Umlauten)
xcrun simctl spawn "$UDID" defaults write .GlobalPreferences AppleKeyboards -array "$KB"
xcrun simctl spawn "$UDID" defaults write .GlobalPreferences AppleKeyboardsExpanded -int 1
xcrun simctl status_bar "$UDID" override --time 09:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported || true
reinstall() { xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1; xcrun simctl uninstall "$UDID" "$BID" >/dev/null 2>&1; xcrun simctl install "$UDID" "$APP" >/dev/null; }
shot() { sleep "$D"; xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null; echo "  saved $1.png"; }
open_doc() { xcrun simctl openurl "$UDID" "file://$DEMO/$1"; sleep 3; }

# Suche: Team-Notiz mit vorbelegtem Begriff „Release"
reinstall
xcrun simctl launch "$UDID" "$BID" "${LA[@]}" -mdviewerFind Release >/dev/null; sleep 5
open_doc "$TEAM"
shot "$FIND"

# Tabs (nur iPad): drei Dokumente öffnen, Übersicht zuletzt -> aktiv
if [[ $FORM == ipad ]]; then
  reinstall
  xcrun simctl launch "$UDID" "$BID" "${LA[@]}" >/dev/null; sleep 5
  open_doc "$MATRIX"; open_doc "$CODE"; open_doc "$TEAM"
  shot "$OV"
fi
xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
echo "done -> $OUT"
