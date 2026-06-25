#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/docs/app-store/screenshots}"
expected_files=(
  "01-overview.png"
  "02-cpu-memory.png"
  "03-network-storage.png"
  "04-widget-popover.png"
  "05-settings-history.png"
)
expected_files_text="Expected files: 01-overview.png, 02-cpu-memory.png, 03-network-storage.png, 04-widget-popover.png, 05-settings-history.png."

if [[ ! -d "$SCREENSHOT_DIR" ]]; then
  echo "Screenshot directory not found: $SCREENSHOT_DIR" >&2
  exit 1
fi

shopt -s nullglob
screenshots=(
  "$SCREENSHOT_DIR"/*.png
  "$SCREENSHOT_DIR"/*.jpg
  "$SCREENSHOT_DIR"/*.jpeg
)
shopt -u nullglob

count="${#screenshots[@]}"
if (( count != ${#expected_files[@]} )); then
  echo "Mac App Store screenshots must include exactly ${#expected_files[@]} images in $SCREENSHOT_DIR." >&2
  echo "$expected_files_text" >&2
  exit 1
fi

for expected_file in "${expected_files[@]}"; do
  if [[ ! -f "$SCREENSHOT_DIR/$expected_file" ]]; then
    echo "Missing expected screenshot: $expected_file" >&2
    echo "$expected_files_text" >&2
    exit 1
  fi
done

for screenshot in "${screenshots[@]}"; do
  case "$(basename "$screenshot")" in
    01-overview.png|02-cpu-memory.png|03-network-storage.png|04-widget-popover.png|05-settings-history.png)
      ;;
    *)
      echo "Unexpected screenshot file: $(basename "$screenshot")" >&2
      echo "$expected_files_text" >&2
      exit 1
      ;;
  esac

  width="$(sips -g pixelWidth -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelWidth -g pixelHeight "$screenshot" 2>/dev/null | awk '/pixelHeight/ { print $2 }')"
  size="${width}x${height}"

  case "$size" in
    2880x1800|2560x1600|1440x900|1280x800)
      ;;
    *)
      echo "Unsupported screenshot size for $(basename "$screenshot"): $size" >&2
      echo "Use one of: 2880x1800, 2560x1600, 1440x900, 1280x800." >&2
      exit 1
      ;;
  esac
done

echo "Validated $count Mac App Store screenshot(s) in $SCREENSHOT_DIR."
