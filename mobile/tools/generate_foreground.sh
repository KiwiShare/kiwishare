#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT_DIR/assets/icons/kiwishare-app-icon_V1.5/android/adaptive/ic_launcher_foreground.png"
DST="$ROOT_DIR/android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png"

# Preserve the approved colour, alpha, and adaptive safe-zone padding exactly.
mkdir -p "$(dirname "$DST")"
cp "$SRC" "$DST"
bash "$ROOT_DIR/tools/validate_icons.sh" --android-only
