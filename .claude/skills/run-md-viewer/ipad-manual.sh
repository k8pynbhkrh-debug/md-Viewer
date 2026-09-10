#!/bin/bash
# iPad 04-07 for one language. Single install, then openurl+shot per doc with a
# hard kill on a hung `simctl openurl` (the doc still opens despite the hang).
set -uo pipefail
UDID="$1"; OUT="$2"; LANG="$3"
REPO="/Users/eric/worktrees/md-viewer/T-2026-003"
APP="$REPO/build/DerivedData-sim/Build/Products/Debug-iphonesimulator/md Viewer.app"
BID="com.eribert.md-Viewer"
mkdir -p "$OUT"
if [ "$LANG" = de ]; then
  DEMO="$REPO/App-Store-Screenshots/demo-dokumente/de"; LOCALE=de_DE
  DOCS=("Team-Notiz.md:04-uebersicht" "Release-Matrix.md:05-tabelle" "Code-Beispiele.md:06-code" "Sprachen & Emoji.md:07-sprachen")
else
  DEMO="$REPO/App-Store-Screenshots/demo-dokumente/en"; LOCALE=en_US
  DOCS=("Team-Note.md:04-overview" "Release-Matrix.md:05-table" "Code-Examples.md:06-code" "Languages & Emoji.md:07-languages")
fi

xcrun simctl status_bar "$UDID" override --time 09:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported || true
xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
xcrun simctl uninstall "$UDID" "$BID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP" >/dev/null
xcrun simctl launch "$UDID" "$BID" -AppleLanguages "($LANG)" -AppleLocale "$LOCALE" >/dev/null
sleep 3

for entry in "${DOCS[@]}"; do
  doc="${entry%%:*}"; name="${entry##*:}"
  xcrun simctl openurl "$UDID" "file://$DEMO/$doc" &
  op=$!
  sleep 12
  kill "$op" 2>/dev/null || true
  wait "$op" 2>/dev/null || true
  sleep 2
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "  saved $name.png"
  # back to empty state so the next doc opens fresh over it
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BID" -AppleLanguages "($LANG)" -AppleLocale "$LOCALE" >/dev/null
  sleep 2
done
xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
echo "done -> $OUT"
