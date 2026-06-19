#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/System Dashboard.app"
APP_BUNDLE_IDENTIFIER="${APP_BUNDLE_IDENTIFIER:-local.system-dashboard}"
WIDGET_BUNDLE_IDENTIFIER="${WIDGET_BUNDLE_IDENTIFIER:-$APP_BUNDLE_IDENTIFIER.widget}"
PACKAGE_CONFIGURATION="${PACKAGE_CONFIGURATION:-Release}"
PACKAGE_SIGNING_MODE="${PACKAGE_SIGNING_MODE:-adhoc}"
PACKAGE_DERIVED_DATA_PATH="${PACKAGE_DERIVED_DATA_PATH:-$ROOT_DIR/.build/package-derived-data}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

case "$PACKAGE_SIGNING_MODE" in
  adhoc|xcode)
    ;;
  *)
    echo "Unsupported PACKAGE_SIGNING_MODE: $PACKAGE_SIGNING_MODE" >&2
    echo "Use PACKAGE_SIGNING_MODE=adhoc for local testing or PACKAGE_SIGNING_MODE=xcode for Apple-managed signing." >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"
swift scripts/generate-app-icon.swift
APP_BUNDLE_IDENTIFIER="$APP_BUNDLE_IDENTIFIER" \
WIDGET_BUNDLE_IDENTIFIER="$WIDGET_BUNDLE_IDENTIFIER" \
MARKETING_VERSION="$MARKETING_VERSION" \
CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION" \
DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  scripts/generate-xcodeproj.rb

BUILD_SETTINGS=(
  APP_BUNDLE_IDENTIFIER="$APP_BUNDLE_IDENTIFIER"
  WIDGET_BUNDLE_IDENTIFIER="$WIDGET_BUNDLE_IDENTIFIER"
)

BUILD_SETTINGS+=(MARKETING_VERSION="$MARKETING_VERSION")
BUILD_SETTINGS+=(CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION")

if [[ -n "$DEVELOPMENT_TEAM" ]]; then
  BUILD_SETTINGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

if [[ "$PACKAGE_SIGNING_MODE" == "adhoc" ]]; then
  BUILD_SETTINGS+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild \
  -project SystemDashboard.xcodeproj \
  -scheme SystemDashboard \
  -configuration "$PACKAGE_CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$PACKAGE_DERIVED_DATA_PATH" \
  "${BUILD_SETTINGS[@]}" \
  build

BUILT_APP="$PACKAGE_DERIVED_DATA_PATH/Build/Products/$PACKAGE_CONFIGURATION/System Dashboard.app"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Built app not found for configuration $PACKAGE_CONFIGURATION" >&2
  exit 1
fi

rm -rf "$APP_DIR"
cp -R "$BUILT_APP" "$APP_DIR"

if [[ "$PACKAGE_SIGNING_MODE" == "adhoc" ]]; then
  codesign --force --sign - \
    --entitlements "$ROOT_DIR/Resources/SystemDashboardWidget.entitlements" \
    "$APP_DIR/Contents/PlugIns/SystemDashboardWidgetExtension.appex"

  codesign --force --sign - \
    --entitlements "$ROOT_DIR/Resources/SystemDashboard.entitlements" \
    "$APP_DIR"
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f -R -trusted "$APP_DIR"

echo "$APP_DIR"
