#!/usr/bin/env bash
# Render tools/assets/butler-freecad-icon.svg into a macOS .icns and drop it
# in $1 (the destination .icns path). Installs librsvg (rsvg-convert) via
# Homebrew if it isn't already on PATH.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$PROJECT_DIR/tools/assets/butler-freecad-icon.svg"
DEST_ICNS="${1:?usage: macos-build-icon.sh <dest.icns>}"

if ! command -v rsvg-convert >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
  brew install librsvg >/dev/null 2>&1 || true
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not available -- skipped building custom icon." \
       "Install with 'brew install librsvg'." >&2
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/icon.iconset"
mkdir -p "$ICONSET"

# name size
sizes="icon_16x16 16
icon_16x16@2x 32
icon_32x32 32
icon_32x32@2x 64
icon_128x128 128
icon_128x128@2x 256
icon_256x256 256
icon_256x256@2x 512
icon_512x512 512
icon_512x512@2x 1024"

while IFS=' ' read -r name px; do
  [[ -z "$name" ]] && continue
  rsvg-convert -w "$px" -h "$px" "$SVG" -o "$ICONSET/$name.png"
done <<< "$sizes"

iconutil -c icns "$ICONSET" -o "$DEST_ICNS"
echo "Built icon: $DEST_ICNS"
