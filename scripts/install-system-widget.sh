#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_APP="$ROOT_DIR/dist/Pulse Dock.app"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/Pulse Dock.app"
WIDGET_EXTENSION="$INSTALLED_APP/Contents/PlugIns/PulseDockWidgetExtension.appex"
SOURCE_WIDGET_EXTENSION="$SOURCE_APP/Contents/PlugIns/PulseDockWidgetExtension.appex"
LEGACY_APP="$INSTALL_DIR/System Dashboard.app"
LEGACY_WIDGET_EXTENSION="$LEGACY_APP/Contents/PlugIns/SystemDashboardWidgetExtension.appex"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-local.pulsedock}"
WIDGET_BUNDLE_IDENTIFIER="${WIDGET_BUNDLE_IDENTIFIER:-$APP_BUNDLE_IDENTIFIER.widget}"
LEGACY_WIDGET_BUNDLE_IDENTIFIER="${LEGACY_WIDGET_BUNDLE_IDENTIFIER:-local.system-dashboard.widget}"
EXTRA_LEGACY_WIDGET_BUNDLE_IDENTIFIERS=("com.qiaoni.systemdashboard.widget")

validate_bundle_identifier() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$ ]]; then
    echo "$name is not a valid bundle identifier: $value" >&2
    exit 2
  fi
}

read_bundle_identifier() {
  local app="$1"
  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist" 2>/dev/null || true
}

unregister_widget_extension_paths() {
  local bundle_identifier="$1"
  while IFS= read -r registered_extension; do
    [[ "$registered_extension" == *SystemDashboardWidgetExtension.appex ]] || continue
    pluginkit -r "$registered_extension" >/dev/null 2>&1 || true
  done < <(pluginkit -m -A -D -v -i "$bundle_identifier" 2>/dev/null | awk -F '\t' '{print $NF}')
}

unregister_legacy_widget_registrations() {
  pluginkit -e ignore -i "$LEGACY_WIDGET_BUNDLE_IDENTIFIER" >/dev/null 2>&1 || true
  unregister_widget_extension_paths "$LEGACY_WIDGET_BUNDLE_IDENTIFIER"

  local extra_bundle_identifier
  for extra_bundle_identifier in "${EXTRA_LEGACY_WIDGET_BUNDLE_IDENTIFIERS[@]}"; do
    pluginkit -e ignore -i "$extra_bundle_identifier" >/dev/null 2>&1 || true
    unregister_widget_extension_paths "$extra_bundle_identifier"
  done
}

uninstall_legacy_system_dashboard() {
  unregister_legacy_widget_registrations
  [[ -d "$LEGACY_APP" ]] || return 0

  local legacy_bundle_id
  legacy_bundle_id="$(read_bundle_identifier "$LEGACY_APP")"
  if [[ "$legacy_bundle_id" == "local.system-dashboard" ]]; then
    osascript - "$legacy_bundle_id" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  tell application id (item 1 of argv) to quit
end run
APPLESCRIPT
    pkill -f "$LEGACY_APP/Contents/MacOS/System Dashboard" >/dev/null 2>&1 || true
    pkill -f "$LEGACY_APP/Contents/PlugIns/SystemDashboardWidgetExtension.appex" >/dev/null 2>&1 || true
    pluginkit -r "$LEGACY_WIDGET_EXTENSION" >/dev/null 2>&1 || true
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
      -u "$LEGACY_APP" >/dev/null 2>&1 || true
    rm -rf "$LEGACY_APP"
  fi
}

wait_for_widget_registration() {
  local attempt
  for attempt in 1 2 3 4 5; do
    pluginkit -a "$WIDGET_EXTENSION" >/dev/null 2>&1 || true
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
validate_bundle_identifier LEGACY_WIDGET_BUNDLE_IDENTIFIER "$LEGACY_WIDGET_BUNDLE_IDENTIFIER"

mkdir -p "$INSTALL_DIR"
uninstall_legacy_system_dashboard

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
  -f "$INSTALLED_APP"

wait_for_widget_registration
pluginkit -e use -i "$WIDGET_BUNDLE_IDENTIFIER" >/dev/null || true

echo "$INSTALLED_APP"
