#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Pulse Dock"
PROJECT_NAME="PulseDock.xcodeproj"
SCHEME_NAME="PulseDock"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/run-derived}"
BUNDLE_ID="com.ifonly3.pulsedock"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cd "$ROOT_DIR"

stop_existing_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
  xcodebuild \
    -quiet \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
  /usr/bin/osascript -e "tell application \"$APP_NAME\" to activate" >/dev/null 2>&1 || true
}

verify_app() {
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
}

case "$MODE" in
  run)
    stop_existing_app
    build_app
    open_app
    ;;
  --debug|debug)
    stop_existing_app
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    stop_existing_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    stop_existing_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    stop_existing_app
    build_app
    open_app
    verify_app
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
