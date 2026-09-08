#!/bin/bash
# English App Store screenshots for md Viewer (iPhone 6.9" / iPad 13").
# Prereq: build the sim app once with driver.sh build.
# Usage: screenshots-ios.sh <sim-udid> <out-dir> [iphone|ipad]
#   iPhone 17 Pro Max  -> App-Store-Screenshots/en/iPhone-6.9
#   iPad Pro 13" (M4)  -> App-Store-Screenshots/en/iPad-13
# Notes: the sim's software keyboard + the one-time "multilingual typing"
# sheet are the fiddly bits — this script sends Return/Cmd+K via System
# Events to deal with them. iPad shot 02 may still catch the keyboard; if
# so re-shoot it with a Cmd+K toggle. iPad M-series sims draw a grey
# bezel arc bottom-right; paint it white afterwards.
set -uo pipefail

UDID="$1"
OUT="$2"
FORM="${3:-iphone}"
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$REPO/build/DerivedData-sim/Build/Products/Debug-iphonesimulator/md Viewer.app"
BID="com.eribert.md-Viewer"
DEMO="$REPO/App-Store-Screenshots/demo-dokumente/en"
LANG_ARGS=(-AppleLanguages "(en)" -AppleLocale en_US)
D="${SHOT_DELAY:-5}"

mkdir -p "$OUT"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" override --time 09:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode notSupported || true

focus_sim() { osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true; sleep 0.6; }
key_return() { focus_sim; osascript -e 'tell application "System Events" to keystroke return' >/dev/null 2>&1 || true; }
key_cmd_k()  { focus_sim; osascript -e 'tell application "System Events" to keystroke "k" using command down' >/dev/null 2>&1 || true; }

reinstall() {
  xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$UDID" "$BID" >/dev/null 2>&1 || true
  xcrun simctl install "$UDID" "$APP" >/dev/null
}
shot() { sleep "$D"; xcrun simctl io "$UDID" screenshot "$OUT/$1.png" >/dev/null; echo "  saved $1.png"; }
open_doc() { xcrun simctl openurl "$UDID" "file://$DEMO/$1"; }

# 01 — empty state, Paste active (clipboard primed)
reinstall
printf '# Meeting notes\n\n- Ship the English build\n- Refresh the screenshots\n' | xcrun simctl pbcopy "$UDID"
xcrun simctl launch "$UDID" "$BID" "${LANG_ARGS[@]}" >/dev/null
shot 01-empty-state

# 02 — new document from pasted text (draft in editor). Dismiss the one-time
# "multilingual typing" sheet with Return, then screenshot (no keyboard).
reinstall
xcrun simctl launch "$UDID" "$BID" "${LANG_ARGS[@]}" \
  -mdviewerDraft $'# Release checklist\n\n- [x] Localize the app UI\n- [ ] Refresh the screenshots\n- [ ] Submit for review\n\nStarted from clipboard text. The red checkmark saves it as a new **.md** file.' >/dev/null
sleep 3
key_return                      # dismiss multilingual sheet if present
sleep 1
shot 02-new-from-text

# 03 — editing an existing file, software keyboard shown
reinstall
xcrun simctl launch "$UDID" "$BID" "${LANG_ARGS[@]}" -mdviewerScreenshotEdit >/dev/null
sleep 2
open_doc "Note.md"
sleep 2
key_return                      # dismiss sheet (harmless newline if it lands in editor)
sleep 1
key_cmd_k                       # raise software keyboard
shot 03-editing

# 04-07 — rendered documents
render_shot() {
  reinstall
  xcrun simctl launch "$UDID" "$BID" "${LANG_ARGS[@]}" >/dev/null
  sleep 2
  open_doc "$1"
  shot "$2"
}
render_shot "Team-Note.md"        04-overview
render_shot "Release-Matrix.md"   05-table
render_shot "Code-Examples.md"    06-code
render_shot "Languages & Emoji.md" 07-languages

xcrun simctl terminate "$UDID" "$BID" >/dev/null 2>&1 || true
echo "done -> $OUT"
