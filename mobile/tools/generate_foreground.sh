#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_MASTER="$ROOT_DIR/assets/icons/kiwishare-app-icon_V1.5/master/kiwishare-mark-green-4096.png"
DST="$ROOT_DIR/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_foreground.png"
BACKUP="$DST.bak"

echo "Generate foreground: master=$ASSET_MASTER -> dst=$DST"

if [ ! -f "$ASSET_MASTER" ]; then
  echo "ERROR: master asset not found: $ASSET_MASTER" >&2
  exit 2
fi

mkdir -p "$(dirname "$DST")"
if [ -f "$DST" ]; then
  echo "Backing up existing foreground to $BACKUP"
  cp -v "$DST" "$BACKUP"
fi


try_magick() {
  if command -v magick >/dev/null 2>&1; then
    echo "Using ImageMagick (magick) to create white foreground"
    magick convert "$ASSET_MASTER" -resize 432x432 -alpha set -background none -gravity center -extent 432x432 PNG32:- | \
      magick convert - -alpha extract PNG32:- | \
      magick convert - -size 432x432 xc:white -compose DstIn -composite "$DST"
    return 0
  fi
  if command -v convert >/dev/null 2>&1; then
    echo "Using ImageMagick (convert) to create white foreground"
    convert "$ASSET_MASTER" -resize 432x432 -alpha set -background none -gravity center -extent 432x432 PNG32:- | \
      convert - -alpha extract PNG32:- | \
      convert - -size 432x432 xc:white -compose DstIn -composite "$DST"
    return 0
  fi
  return 1
}

try_sips() {
  # sips cannot recolor reliably; keep as a last-resort resize-only (will preserve original colors)
  if command -v sips >/dev/null 2>&1; then
    echo "sips available but cannot guarantee white-only mark; skipping for strict requirement"
    return 1
  fi
  return 1
}

try_python() {
  if command -v python3 >/dev/null 2>&1; then
    echo "Trying Python+Pillow to resize (requires Pillow to be installed)"
    python3 - <<PY || return 1
from PIL import Image
src = "${ASSET_MASTER}"
dst = "${DST}"
img = Image.open(src).convert('RGBA')
img = img.resize((432,432), Image.LANCZOS)
img.save(dst)
PY
    return 0
  fi
  return 1
}

if try_magick; then
  echo "Foreground generated using ImageMagick."
elif try_python; then
  echo "Foreground generated using Python+Pillow."
else
  echo "ERROR: No available tool to generate white-only foreground. Install ImageMagick or Pillow (pip install Pillow), or run the conversion manually." >&2
  exit 3
fi

echo "Verifying generated file properties:"
if command -v sips >/dev/null 2>&1; then
  sips -g hasAlpha -g pixelWidth -g pixelHeight "$DST" || true
else
  echo "(sips not available to report properties)"
fi

echo "Running validation script..."
"$ROOT_DIR/tools/validate_icons.sh"

echo "Done. If validation passed, please run Flutter analyze/test/build on your machine."

