#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_INFO_PLIST="$ROOT_DIR/Resources/AppInfo.plist"

expected_privacy_url="https://ifonly3.github.io/pulsedock/privacy-policy/"
expected_support_url="https://ifonly3.github.io/pulsedock/support/"

privacy_url="$(plutil -extract PulseDockPrivacyPolicyURL raw -o - "$APP_INFO_PLIST")"
support_url="$(plutil -extract PulseDockSupportURL raw -o - "$APP_INFO_PLIST")"

if [[ "$privacy_url" != "$expected_privacy_url" ]]; then
  echo "Unexpected PulseDockPrivacyPolicyURL: $privacy_url" >&2
  echo "Expected: $expected_privacy_url" >&2
  exit 1
fi

if [[ "$support_url" != "$expected_support_url" ]]; then
  echo "Unexpected PulseDockSupportURL: $support_url" >&2
  echo "Expected: $expected_support_url" >&2
  exit 1
fi

required_page_paths=(
  "$ROOT_DIR/docs/privacy-policy/index.html"
  "$ROOT_DIR/docs/support/index.html"
)

required_page_headings=(
  "Pulse Dock Privacy Policy"
  "Pulse Dock Support"
)

for index in "${!required_page_paths[@]}"; do
  page="${required_page_paths[$index]}"
  heading="${required_page_headings[$index]}"

  if [[ ! -s "$page" ]]; then
    echo "Missing public page source: $page" >&2
    exit 1
  fi

  if ! grep -Fq "$heading" "$page"; then
    echo "Public page is missing expected heading: $page" >&2
    exit 1
  fi
done

if [[ "${CHECK_PUBLIC_URLS:-0}" == "1" ]]; then
  for url in "$privacy_url" "$support_url"; do
    status="$(curl --max-time 15 -L -o /dev/null -s -w "%{http_code}" "$url")"
    if [[ "$status" != "200" ]]; then
      echo "Public URL did not return HTTP 200: $url returned $status" >&2
      exit 1
    fi
  done

  echo "Validated local public page sources and live HTTP 200 URLs."
else
  echo "Validated local public page sources."
  echo "Set CHECK_PUBLIC_URLS=1 to verify published GitHub Pages URLs return HTTP 200."
fi
