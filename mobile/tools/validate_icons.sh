#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_PACK="$ROOT_DIR/assets/icons/kiwishare-app-icon_V1.5"

echo "Validating icon assets..."

fail=0
check_file() {
  if [ ! -f "$1" ]; then
    echo "MISSING: $1"
    fail=1
  else
    echo "FOUND: $1"
  fi
}

# iOS required files (from Contents.json)
IOS_APPICONSET="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
for f in Icon-App-20x20@1x.png Icon-App-20x20@2x.png Icon-App-20x20@3x.png \
         Icon-App-29x29@1x.png Icon-App-29x29@2x.png Icon-App-29x29@3x.png \
         Icon-App-40x40@1x.png Icon-App-40x40@2x.png Icon-App-40x40@3x.png \
         Icon-App-60x60@2x.png Icon-App-60x60@3x.png \
         Icon-App-76x76@1x.png Icon-App-76x76@2x.png Icon-App-83.5x83.5@2x.png \
         Icon-App-1024x1024@1x.png Icon-App-Dark-1024.png Icon-App-Tinted-1024.png; do
  check_file "$IOS_APPICONSET/$f"
done

# Android legacy
ANDROID_RES_DIR="$ROOT_DIR/android/app/src/main/res"
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  check_file "$ANDROID_RES_DIR/mipmap-$d/ic_launcher.png"
done

# Adaptive assets
check_file "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher.xml"
check_file "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_foreground.png"
check_file "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_background.png"
check_file "$ANDROID_RES_DIR/drawable-anydpi-v33/ic_launcher_monochrome.png"
check_file "$ANDROID_RES_DIR/values/ic_launcher_colors.xml"

# XML content checks
echo "Checking adaptive XML content rules..."
if [ -f "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher.xml" ]; then
  if grep -q "<monochrome" "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher.xml"; then
    echo "ERROR: v26 ic_launcher.xml must NOT contain <monochrome>"
    fail=1
  else
    echo "OK: v26 ic_launcher.xml contains no monochrome"
  fi
fi

if [ -f "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_round.xml" ]; then
  if grep -q "<monochrome" "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_round.xml"; then
    echo "ERROR: v26 ic_launcher_round.xml must NOT contain <monochrome>"
    fail=1
  else
    echo "OK: v26 ic_launcher_round.xml contains no monochrome"
  fi
fi

if [ -f "$ANDROID_RES_DIR/mipmap-anydpi-v33/ic_launcher.xml" ]; then
  if grep -q "<monochrome" "$ANDROID_RES_DIR/mipmap-anydpi-v33/ic_launcher.xml"; then
    if ! grep -q "@drawable/ic_launcher_monochrome" "$ANDROID_RES_DIR/mipmap-anydpi-v33/ic_launcher.xml"; then
      echo "ERROR: v33 ic_launcher.xml monochrome must reference @drawable/ic_launcher_monochrome"
      fail=1
    else
      echo "OK: v33 ic_launcher.xml contains monochrome referencing @drawable"
    fi
  else
    echo "ERROR: v33 ic_launcher.xml must contain <monochrome> referencing @drawable/ic_launcher_monochrome"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "Validation FAILED"
  exit 2
fi

echo "Validation PASSED: all required files present."

echo "Checking image dimensions (sips on macOS)..."
check_dim() {
  if command -v sips >/dev/null 2>&1; then
    dims=$(sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixelWidth|pixelHeight/{print $2}' | xargs)
    echo "$1 -> $dims"
  else
    echo "sips not available; skipping dimension checks for $1"
  fi
}

check_dim "$IOS_APPICONSET/Icon-App-1024x1024@1x.png" || true
check_dim "$ANDROID_RES_DIR/mipmap-xxxhdpi/ic_launcher.png" || true

echo "Validation finished."
