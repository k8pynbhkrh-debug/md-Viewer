#!/usr/bin/env bash
# Driver for building, launching, and driving the "md Viewer" SwiftUI app
# in the iOS Simulator. Run from anywhere; paths below are resolved
# relative to this script's location.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"          # repo root
XCODE_DIR="$UNIT_ROOT/md Viewer"                          # contains .xcodeproj
PROJECT="md Viewer.xcodeproj"
SCHEME="md Viewer"
BUNDLE_ID="com.eribert.md-Viewer"
BUILD_DIR="$UNIT_ROOT/build/DerivedData-sim"              # under gitignored build/
DEVICE_NAME="${MD_VIEWER_SIM_NAME:-iPhone 17}"

log() { echo "[driver] $*" >&2; }

resolve_device_id() {
  local id
  id=$(xcrun simctl list devices available -j \
    | /usr/bin/python3 -c "
import json,sys
data=json.load(sys.stdin)
name='$DEVICE_NAME'
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d['name']==name:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
")
  echo "$id"
}

DEVICE_ID="${MD_VIEWER_SIM_UDID:-$(resolve_device_id)}"
[ -n "$DEVICE_ID" ] || { log "No simulator named '$DEVICE_NAME' found. Set MD_VIEWER_SIM_UDID or MD_VIEWER_SIM_NAME."; exit 1; }

app_path() {
  echo "$BUILD_DIR/Build/Products/Debug-iphonesimulator/md Viewer.app"
}

cmd_build() {
  log "Building for device $DEVICE_ID ..."
  (cd "$XCODE_DIR" && xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$BUILD_DIR" \
    -configuration Debug \
    build)
  log "Built: $(app_path)"
}

cmd_boot() {
  log "Booting simulator $DEVICE_ID ..."
  open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
  xcrun simctl bootstatus "$DEVICE_ID" -b
}

cmd_install() {
  log "Installing app ..."
  xcrun simctl install "$DEVICE_ID" "$(app_path)"
}

cmd_launch() {
  log "Launching $BUNDLE_ID ..."
  xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"
}

cmd_terminate() {
  xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" || true
}

cmd_open() {
  local file="$1"
  [ -f "$file" ] || { log "No such file: $file"; exit 1; }
  local abs
  abs=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
  log "Opening $abs in app ..."
  xcrun simctl openurl "$DEVICE_ID" "file://$abs"
}

cmd_screenshot() {
  local out="${1:-$SKILL_DIR/screenshot.png}"
  xcrun simctl io "$DEVICE_ID" screenshot "$out"
  log "Screenshot saved to $out"
}

cmd_full() {
  cmd_build
  cmd_boot
  cmd_install
  cmd_launch
}

cmd_test() {
  log "Running unit tests on device $DEVICE_ID ..."
  (cd "$XCODE_DIR" && xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$BUILD_DIR")
}

cmd_mutate() {
  log "Running mutation testing (muter) ..."
  (cd "$XCODE_DIR" && muter run "$@")
}

case "${1:-}" in
  build) cmd_build ;;
  boot) cmd_boot ;;
  install) cmd_install ;;
  launch) cmd_launch ;;
  terminate) cmd_terminate ;;
  open) cmd_open "${2:?usage: driver.sh open <path/to/file.md>}" ;;
  screenshot) cmd_screenshot "${2:-}" ;;
  full) cmd_full ;;
  test) cmd_test ;;
  mutate) shift; cmd_mutate "$@" ;;
  device-id) echo "$DEVICE_ID" ;;
  *)
    cat >&2 <<EOF
Usage: driver.sh <command> [args]

Commands:
  build                 xcodebuild the app for the simulator
  boot                  boot the simulator (opens Simulator.app)
  install               install the built .app onto the simulator
  launch                launch the app (foreground)
  terminate             terminate the running app
  open <file>           open a .md file in the running app (simulates Files/Share Sheet)
  screenshot [path]     save a PNG screenshot (default: skill_dir/screenshot.png)
  full                  build + boot + install + launch
  test                  run the md ViewerTests unit test target (xcodebuild test)
  mutate [muter args]   run mutation testing (muter run ...) — see muter.conf.yml
  device-id             print the resolved simulator UDID

Env overrides:
  MD_VIEWER_SIM_NAME    simulator name to target (default: "iPhone 17")
  MD_VIEWER_SIM_UDID    exact simulator UDID (skips name lookup)
EOF
    exit 1
    ;;
esac
