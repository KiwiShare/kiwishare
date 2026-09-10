#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSET_PACK="$ROOT_DIR/assets/icons/kiwishare-app-icon_V1.5"

case "${1:-}" in
  ""|--android-only) ;;
  *) echo "Usage: $0 [--android-only]" >&2; exit 2 ;;
esac

echo "Installing KiwiShare icons from: $ASSET_PACK"

if [ "${1:-}" != "--android-only" ]; then
# iOS: copy legacy and modern assets into AppIcon.appiconset
IOS_APPICONSET="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$IOS_APPICONSET"

echo "Copying iOS legacy icons..."
cp -v "$ASSET_PACK/ios/legacy/"*.png "$IOS_APPICONSET/"

echo "Copying iOS modern 1024px assets (Default/Dark/Tinted)..."
cp -v "$ASSET_PACK/ios/modern/AppIcon-Default-1024.png" "$IOS_APPICONSET/Icon-App-1024x1024@1x.png"
cp -v "$ASSET_PACK/ios/modern/AppIcon-Dark-1024.png" "$IOS_APPICONSET/Icon-App-Dark-1024.png"
cp -v "$ASSET_PACK/ios/modern/AppIcon-Tinted-1024.png" "$IOS_APPICONSET/Icon-App-Tinted-1024.png"

fi

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
    echo "ERROR: missing $src" >&2
    exit 2
  fi
done

# Android: adaptive assets and XML
echo "Installing Android adaptive assets and XML..."
# 432px at xxxhdpi (640dpi) represents the required 108dp adaptive layer.
# Never put PNGs in anydpi: Android can downsample them to only a few pixels.
mkdir -p "$ANDROID_RES_DIR/drawable-xxxhdpi"
mkdir -p "$ANDROID_RES_DIR/mipmap-anydpi-v26"
mkdir -p "$ANDROID_RES_DIR/mipmap-anydpi-v33"
mkdir -p "$ANDROID_RES_DIR/drawable-xxxhdpi-v33"

cp -v "$ASSET_PACK/android/adaptive/ic_launcher_foreground.png" "$ANDROID_RES_DIR/drawable-xxxhdpi/ic_launcher_foreground.png"
cp -v "$ASSET_PACK/android/adaptive/ic_launcher_background.png" "$ANDROID_RES_DIR/drawable-xxxhdpi/ic_launcher_background.png"
cp -v "$ASSET_PACK/android/adaptive/ic_launcher_monochrome.png" "$ANDROID_RES_DIR/drawable-xxxhdpi-v33/ic_launcher_monochrome.png"

# Generate platform-specific wrappers; the source-pack XML is not API-versioned.
for version in 26 33; do
  for name in ic_launcher ic_launcher_round; do
    {
      echo '<?xml version="1.0" encoding="utf-8"?>'
      echo '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">'
      echo '    <background android:drawable="@color/ic_launcher_background" />'
      echo '    <foreground android:drawable="@drawable/ic_launcher_foreground" />'
      if [ "$version" = 33 ]; then
        echo '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />'
      fi
      echo '</adaptive-icon>'
    } | python3 -c '
import sys
from pathlib import Path
path = Path(sys.argv[1])
content = sys.stdin.read()
# Preserve existing line endings when the wrapper already matches.
if not path.exists() or path.read_text().strip() != content.strip():
    path.write_text(content)
' "$ANDROID_RES_DIR/mipmap-anydpi-v$version/$name.xml"
  done
done

mkdir -p "$ANDROID_RES_DIR/values"
cat > "$ANDROID_RES_DIR/values/ic_launcher_aliases.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <item type="mipmap" name="ic_launcher_round">@mipmap/ic_launcher</item>
</resources>
XML

# Keep the existing shared colour file: it also contains notification colours.
bash "$ROOT_DIR/tools/validate_icons.sh" --android-only
echo "Icon installation complete."
