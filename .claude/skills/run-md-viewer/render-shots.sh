#!/bin/bash
# Regenerate the rendered-reader shots (04-07) for one language set.
# 1.4 changed the reader toolbar (Select Text / Copy All buttons).
# Usage: render-shots.sh <sim-udid> <out-dir> <de|en>
set -uo pipefail
UDID="$1"; OUT="$2"; LANG="$3"
REPO="/Users/eric/worktrees/md-viewer/T-2026-003"
APP="$REPO/build/DerivedData-sim/Build/Products/Debug-iphonesimulator/md Viewer.app"
BID="com.eribert.md-Viewer"
D="${SHOT_DELAY:-8}"
mkdir -p "$OUT"

if [ "$LANG" = "de" ]; then
  DEMO="$REPO/App-Store-Screenshots/demo-dokumente/de"
  LOCALE="de_DE"
  DOCS=("Team-Notiz.md:04-uebersicht" "Release-Matrix.md:05-tabelle" "Code-Beispiele.md:06-code" "Sprachen & Emoji.md:07-sprachen")
else
  DEMO="$REPO/App-Store-Screenshots/demo-dokumente/en"
  LOCALE="en_US"
  DOCS=("Team-Note.md:04-overview" "Release-Matrix.md:05-table" "Code-Examples.md:06-code" "Languages & Emoji.md:07-languages")
fi

xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
# German system status bar (matches the existing 01-03 shots), pinned time/date.
xcrun simctl status_bar "$UDID" override --time 09:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported || true

render() {
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$UDID" "$BID" >/dev/null 2>&1 || true
  xcrun simctl install "$UDID" "$APP" >/dev/null
  xcrun simctl launch "$UDID" "$BID" -AppleLanguages "($LANG)" -AppleLocale "$LOCALE" >/dev/null
  sleep 2
  xcrun simctl openurl "$UDID" "file://$DEMO/$1"
  sleep "$D"
  xcrun simctl io "$UDID" screenshot "$OUT/$2.png" >/dev/null
  echo "  saved $2.png"
}
for entry in "${DOCS[@]}"; do
  render "${entry%%:*}" "${entry##*:}"
done
xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
echo "done -> $OUT"
