#!/bin/bash
# English Mac App Store screenshots for md Viewer (Mac Catalyst debug build).
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
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$REPO/build/DerivedData-maccat/Build/Products/Debug-maccatalyst/md Viewer.app"
OUT="$REPO/App-Store-Screenshots/en/Mac"
DEMO="$REPO/App-Store-Screenshots/demo-dokumente/en"
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
  open -n "$APP" --args -AppleLanguages '(en)' -AppleLocale en_US "$@"
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

launch
capture 01-default-app

launch
open_file "Team-Note.md";         capture 02-overview
open_file "Release-Matrix.md";    capture 03-table
open_file "Code-Examples.md";     capture 04-code
open_file "Languages & Emoji.md"; capture 05-languages

launch -mdviewerScreenshotEdit
open_file "Note.md";              capture 06-editing

kill_app
echo "done -> $OUT"
