#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 2
  fi
}

validate_bundle_identifier() {
  local name="$1"
  local value="$2"
  if [[ "$value" == local.* ]]; then
    echo "$name must be a production bundle identifier for App Store archives." >&2
    exit 2
  fi
  if [[ ! "$value" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$ ]]; then
    echo "$name is not a valid bundle identifier: $value" >&2
    exit 2
  fi
}

require_env APP_BUNDLE_IDENTIFIER
require_env DEVELOPMENT_TEAM

WIDGET_BUNDLE_IDENTIFIER="${WIDGET_BUNDLE_IDENTIFIER:-$APP_BUNDLE_IDENTIFIER.widget}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
ARCHIVE_CONFIGURATION="${ARCHIVE_CONFIGURATION:-Release}"
ARCHIVE_DERIVED_DATA_PATH="${ARCHIVE_DERIVED_DATA_PATH:-$ROOT_DIR/.build/archive-derived-data}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/dist/SystemDashboard.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/dist/AppStore}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-YES}"

validate_bundle_identifier APP_BUNDLE_IDENTIFIER "$APP_BUNDLE_IDENTIFIER"
validate_bundle_identifier WIDGET_BUNDLE_IDENTIFIER "$WIDGET_BUNDLE_IDENTIFIER"

if ! [[ "$WIDGET_BUNDLE_IDENTIFIER" == "$APP_BUNDLE_IDENTIFIER".* ]]; then
  echo "WIDGET_BUNDLE_IDENTIFIER must start with APP_BUNDLE_IDENTIFIER followed by a dot." >&2
  exit 2
fi

if [[ -z "$EXPORT_OPTIONS_PLIST" ]]; then
  EXPORT_OPTIONS_PLIST="$ROOT_DIR/.build/AppStoreExportOptions.plist"
  mkdir -p "$(dirname "$EXPORT_OPTIONS_PLIST")"
  cat > "$EXPORT_OPTIONS_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$DEVELOPMENT_TEAM</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST
fi

PROVISIONING_FLAGS=()
if [[ "$ALLOW_PROVISIONING_UPDATES" == "YES" ]]; then
  PROVISIONING_FLAGS+=("-allowProvisioningUpdates")
fi

cd "$ROOT_DIR"
swift scripts/generate-app-icon.swift
APP_BUNDLE_IDENTIFIER="$APP_BUNDLE_IDENTIFIER" \
WIDGET_BUNDLE_IDENTIFIER="$WIDGET_BUNDLE_IDENTIFIER" \
MARKETING_VERSION="$MARKETING_VERSION" \
CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION" \
DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  scripts/generate-xcodeproj.rb

ARCHIVE_BUILD_SETTINGS=(
  APP_BUNDLE_IDENTIFIER="$APP_BUNDLE_IDENTIFIER"
  WIDGET_BUNDLE_IDENTIFIER="$WIDGET_BUNDLE_IDENTIFIER"
  MARKETING_VERSION="$MARKETING_VERSION"
  CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION"
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"
)

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

xcodebuild \
  -project SystemDashboard.xcodeproj \
  -scheme SystemDashboard \
  -configuration "$ARCHIVE_CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$ARCHIVE_DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  "${ARCHIVE_BUILD_SETTINGS[@]}" \
  "${PROVISIONING_FLAGS[@]}" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  "${PROVISIONING_FLAGS[@]}"

echo "$EXPORT_PATH"
