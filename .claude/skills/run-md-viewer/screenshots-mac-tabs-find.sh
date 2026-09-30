#!/bin/bash
# Mac App Store screenshots (Tabs + Suche, iOS 1.6 / macOS 1.5) – Sprache als $1 (de|en).
# Ursprung: screenshots-mac.sh. Englische for md Viewer (Mac Catalyst debug build).
#
# Prereqs:
#   1. Build the Catalyst app once:
#      xcodebuild -project "md Viewer/md Viewer.xcodeproj" -scheme "md Viewer" \
#        -destination 'platform=macOS,variant=Mac Catalyst' \
#        -derivedDataPath build/DerivedData-maccat -configuration Debug build
#   2. Terminal needs Screen Recording + Accessibility permission (for
#      screencapture -l and System Events window resizing).
# Run:  .claude/skills/run-md-viewer/screenshots-mac.sh
set -uo pipefail
L="${1:-en}"
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$REPO/build/DerivedData-maccat/Build/Products/Debug-maccatalyst/md Viewer.app"
OUT="$REPO/App-Store-Screenshots/$L/Mac"
DEMO="$REPO/App-Store-Screenshots/demo-dokumente/$L"
DIR="$(cd "$(dirname "$0")" && pwd)"
TMP="/tmp/md-viewer-mac-raw"
mkdir -p "$OUT" "$TMP"
PID=""

kill_app() {
  osascript -e 'tell application "md Viewer" to quit' >/dev/null 2>&1 || true
  pkill -9 -f "md Viewer.app/Contents/MacOS" 2>/dev/null || true
  sleep 2
}
launch() {  # launch [args...]
  kill_app
  # Sauberer Start: gemerkte Tabs leeren (vorher die echten Einstellungen sichern!)
  defaults delete "$HOME/Library/Containers/com.eribert.md-Viewer/Data/Library/Preferences/com.eribert.md-Viewer" openDocuments >/dev/null 2>&1 || true
  open -n "$APP" --args -AppleLanguages "($L)" -AppleLocale $([[ $L == de ]] && echo de_DE || echo en_US) "$@"
  sleep 5
  PID=$(pgrep -f "DerivedData-maccat/Build/Products/Debug-maccatalyst/md Viewer.app/Contents/MacOS/md Viewer" | head -1)
  [ -n "$PID" ] || { echo "!! no debug pid"; exit 1; }
  osascript >/dev/null 2>&1 <<EOF || true
tell application "System Events" to tell (first process whose unix id is $PID)
  set frontmost to true
  delay 0.3
  tell window 1
    set position to {160, 80}
    set size to {1440, 812}
  end tell
end tell
EOF
  sleep 1
}
open_file() { open -a "$APP" "$DEMO/$1"; sleep 3; }
capture() {  # capture <name>
  osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID) to set frontmost to true" >/dev/null 2>&1 || true
  sleep 0.5
  python3 "$DIR/wincap.py" "$PID" "$TMP/$1.png"
  python3 "$DIR/mac_compose.py" "$TMP/$1.png" "$OUT/$1.png"
  echo "  saved $1.png"
}

if [[ $L == de ]]; then TEAM="Team-Notiz.md"; CODE="Code-Beispiele.md"; OV=02-uebersicht; FIND=05-suchen
else TEAM="Team-Note.md"; CODE="Code-Examples.md"; OV=02-overview; FIND=05-find; fi

# 02 — Übersicht mit drei Tabs (Tab-Leiste im Finder-Stil), Team-Notiz aktiv
launch
open_file "Release-Matrix.md"; open_file "$CODE"; open_file "$TEAM"
capture "$OV"

# 05 — Suche (⌘F) mit vorbelegtem Begriff „Release"
launch -mdviewerFind Release
open_file "$TEAM"
capture "$FIND"

kill_app
echo "done -> $OUT"
