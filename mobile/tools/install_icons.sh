#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_PACK="$ROOT_DIR/assets/icons/kiwishare-app-icon_V1.5"

echo "Installing KiwiShare icons from: $ASSET_PACK"

# iOS: copy legacy and modern assets into AppIcon.appiconset
IOS_APPICONSET="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$IOS_APPICONSET"

echo "Copying iOS legacy icons..."
cp -v "$ASSET_PACK/ios/legacy/"*.png "$IOS_APPICONSET/"

echo "Copying iOS modern 1024px assets (Default/Dark/Tinted)..."
cp -v "$ASSET_PACK/ios/modern/AppIcon-Default-1024.png" "$IOS_APPICONSET/Icon-App-1024x1024@1x.png"
cp -v "$ASSET_PACK/ios/modern/AppIcon-Dark-1024.png" "$IOS_APPICONSET/Icon-App-Dark-1024.png"
cp -v "$ASSET_PACK/ios/modern/AppIcon-Tinted-1024.png" "$IOS_APPICONSET/Icon-App-Tinted-1024.png"

# Android: copy legacy mipmap PNGs
ANDROID_RES_DIR="$ROOT_DIR/android/app/src/main/res"
echo "Copying Android legacy mipmap PNGs..."
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  src="$ASSET_PACK/android/legacy/mipmap-$d/ic_launcher.png"
  dst="$ANDROID_RES_DIR/mipmap-$d/ic_launcher.png"
  if [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp -v "$src" "$dst"
  else
    echo "Warning: missing $src"
  fi
done

# Android: adaptive assets and XML
echo "Installing Android adaptive assets and XML..."
mkdir -p "$ANDROID_RES_DIR/mipmap-anydpi-v26"
mkdir -p "$ANDROID_RES_DIR/mipmap-anydpi-v33"
mkdir -p "$ANDROID_RES_DIR/drawable-anydpi-v33"

cp -v "$ASSET_PACK/android/adaptive/ic_launcher_foreground.png" "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_foreground.png"
cp -v "$ASSET_PACK/android/adaptive/ic_launcher_background.png" "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_background.png"
cp -v "$ASSET_PACK/android/adaptive/ic_launcher_monochrome.png" "$ANDROID_RES_DIR/drawable-anydpi-v33/ic_launcher_monochrome.png"

# copy adaptive xmls (use the versions in the asset pack if present)
if [ -f "$ASSET_PACK/android/adaptive/ic_launcher.xml" ]; then
  cp -v "$ASSET_PACK/android/adaptive/ic_launcher.xml" "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher.xml"
fi
if [ -f "$ASSET_PACK/android/adaptive/ic_launcher_round.xml" ]; then
  cp -v "$ASSET_PACK/android/adaptive/ic_launcher_round.xml" "$ANDROID_RES_DIR/mipmap-anydpi-v26/ic_launcher_round.xml"
fi

echo "Copying adaptive colors resource..."
mkdir -p "$ANDROID_RES_DIR/values"
cp -v "$ASSET_PACK/android/adaptive/colors.xml" "$ANDROID_RES_DIR/values/ic_launcher_colors.xml"

echo "Icon installation complete."
