#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required to run the localization audit." >&2
  exit 2
fi

set +e
matches="$(
  rg --pcre2 -n '[\p{Han}]' \
    Sources/PulseDockApp \
    Sources/PulseDockWidget \
    Sources/SharedMetrics \
    --glob '*.swift'
)"
rgStatus=$?
set -e

if [[ $rgStatus -gt 1 ]]; then
  echo "Localization audit failed because ripgrep exited with status $rgStatus." >&2
  exit "$rgStatus"
fi

if [[ $rgStatus -eq 0 ]]; then
  echo "Found Chinese text in Swift sources. Full English release is blocked until each user-facing string is localized:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "Localization audit passed: no Chinese text remains in Swift sources."
