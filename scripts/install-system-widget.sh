#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/Pulse Dock.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/Pulse Dock.app"
WIDGET_EXTENSION="$INSTALLED_APP/Contents/PlugIns/PulseDockWidgetExtension.appex"
SOURCE_WIDGET_EXTENSION="$SOURCE_APP/Contents/PlugIns/PulseDockWidgetExtension.appex"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-local.pulsedock}"
WIDGET_BUNDLE_IDENTIFIER="${WIDGET_BUNDLE_IDENTIFIER:-$APP_BUNDLE_IDENTIFIER.widget}"

validate_bundle_identifier() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$ ]]; then
    echo "$name is not a valid bundle identifier: $value" >&2
    exit 2
  fi
}

wait_for_widget_registration() {
  local attempt
  for attempt in 1 2 3 4 5; do
    pluginkit -a "$WIDGET_EXTENSION" >/dev/null
    if pluginkit -m -A -D -v -i "$WIDGET_BUNDLE_IDENTIFIER" | grep -F "$WIDGET_EXTENSION" >/dev/null; then
      return 0
    fi
    sleep 0.2
  done

  return 1
}

if [[ ! -d "$SOURCE_APP" ]]; then
  "$ROOT_DIR/scripts/package-app.sh" >/dev/null
fi

validate_bundle_identifier APP_BUNDLE_IDENTIFIER "$APP_BUNDLE_IDENTIFIER"
validate_bundle_identifier WIDGET_BUNDLE_IDENTIFIER "$WIDGET_BUNDLE_IDENTIFIER"

mkdir -p "$INSTALL_DIR"

if pgrep -f "$INSTALLED_APP/Contents/MacOS/Pulse Dock" >/dev/null; then
  osascript - "$APP_BUNDLE_IDENTIFIER" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  tell application id (item 1 of argv) to quit
end run
APPLESCRIPT
  sleep 1
fi

rm -rf "$INSTALLED_APP"
cp -R "$SOURCE_APP" "$INSTALLED_APP"

if [[ -d "$SOURCE_WIDGET_EXTENSION" ]]; then
  pluginkit -r "$SOURCE_WIDGET_EXTENSION" >/dev/null 2>&1 || true
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f -R -trusted "$INSTALLED_APP"

wait_for_widget_registration
pluginkit -e use -i "$WIDGET_BUNDLE_IDENTIFIER" >/dev/null || true

echo "$INSTALLED_APP"
