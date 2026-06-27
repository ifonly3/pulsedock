#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

scanRoots=(
  Sources/PulseDockApp
  Sources/PulseDockWidget
  Sources/SharedMetrics
)

if command -v rg >/dev/null 2>&1; then
  set +e
  matches="$(
    rg --pcre2 -n '\p{Script=Han}' \
      "${scanRoots[@]}" \
      --glob '*.swift'
  )"
  scanStatus=$?
  set -e

  if [[ $scanStatus -gt 1 ]]; then
    echo "Localization audit failed because ripgrep exited with status $scanStatus." >&2
    exit "$scanStatus"
  fi
else
  set +e
  matches="$(
    find "${scanRoots[@]}" -type f -name '*.swift' \
      -exec perl -Mopen=:std,:encoding\(UTF-8\) -ne 'print "$ARGV:$.:$_" if /\p{Script=Han}/; close ARGV if eof' {} +
  )"
  scanStatus=$?
  set -e

  if [[ $scanStatus -ne 0 ]]; then
    echo "Localization audit failed because the portable Swift source scan exited with status $scanStatus." >&2
    exit "$scanStatus"
  fi
fi

if [[ -n "$matches" ]]; then
  echo "Found Chinese text in Swift sources. Full English release is blocked until each user-facing string is localized:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "Localization audit passed: no Chinese text remains in Swift sources."
