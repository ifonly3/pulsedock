#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-Pulse Dock}"
SIZE="${SIZE:-960x640}"
PAGE="${PAGE:-current}"
LANGUAGE_TAG="${LANGUAGE_TAG:-en}"
APPEARANCE_TAG="${APPEARANCE_TAG:-light}"
OUT_DIR="${OUT_DIR:-docs/review/screenshots/responsive}"

WIDTH="${SIZE%x*}"
HEIGHT="${SIZE#*x}"
OUT_PATH="${OUT_DIR}/${LANGUAGE_TAG}-${APPEARANCE_TAG}-${SIZE}-${PAGE}.png"

mkdir -p "$OUT_DIR"

if [[ "${SKIP_RESIZE:-0}" != "1" ]]; then
  osascript <<APPLESCRIPT
tell application "$APP_NAME" to activate
delay 0.6
tell application "System Events"
  tell process "$APP_NAME"
    if not (exists window 1) then error "Pulse Dock window is not open"
    set position of window 1 to {96, 96}
    set size of window 1 to {$WIDTH, $HEIGHT}
  end tell
end tell
APPLESCRIPT
  sleep 0.4
fi

/usr/sbin/screencapture -x "$OUT_PATH"
echo "Captured $OUT_PATH"
