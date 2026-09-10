#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
  ""|--android-only) ;;
  *) echo "Usage: $0 [--android-only]" >&2; exit 2 ;;
esac

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

if [ "${1:-}" != "--android-only" ]; then
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

fi

# Standard-library checks need no image-generation dependency. Byte equality
# preserves the reviewed source PNG's colour, alpha, and padding exactly.
python3 - "$ROOT_DIR" <<'PYTHON'
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
res = root / "android/app/src/main/res"
source = root / "assets/icons/kiwishare-app-icon_V1.5/android"
android = "{http://schemas.android.com/apk/res/android}"

def png(dst, src, size):
    data = dst.read_bytes()
    assert data == src.read_bytes(), f"Source mismatch: {dst}"
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"Invalid PNG: {dst}"
    assert struct.unpack(">II", data[16:24]) == (size, size), f"Wrong dimensions: {dst}"

for density, size in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)]:
    name = f"mipmap-{density}/ic_launcher.png"
    png(res / name, source / "legacy" / name, size)
for name, folder in [("foreground","drawable-xxxhdpi"),("background","drawable-xxxhdpi"),("monochrome","drawable-xxxhdpi-v33")]:
    filename = f"ic_launcher_{name}.png"
    png(res / folder / filename, source / "adaptive" / filename, 432)
# anydpi is for scalable XML here, not density-scaled raster images.
assert not list(res.glob("*-anydpi*/*.png")), "PNG in anydpi can decode to a tiny bitmap"
for version in (26, 33):
    expected = {"background":"@color/ic_launcher_background", "foreground":"@drawable/ic_launcher_foreground"}
    if version == 33:
        expected["monochrome"] = "@drawable/ic_launcher_monochrome"
    for name in ("ic_launcher", "ic_launcher_round"):
        xml = ET.parse(res / f"mipmap-anydpi-v{version}/{name}.xml").getroot()
        assert xml.tag == "adaptive-icon"
        assert len(xml) == len(expected)
        assert {child.tag:child.get(android + "drawable") for child in xml} == expected
colors = ET.parse(res / "values/ic_launcher_colors.xml").getroot()
assert next(c.text for c in colors if c.get("name") == "ic_launcher_background") == "#FAF5EA"
alias = ET.parse(res / "values/ic_launcher_aliases.xml").getroot().find("item")
assert alias.attrib == {"type":"mipmap", "name":"ic_launcher_round"}
assert alias.text == "@mipmap/ic_launcher"
app = ET.parse(root / "android/app/src/main/AndroidManifest.xml").getroot().find("application")
assert app.get(android + "icon") == "@mipmap/ic_launcher"
assert app.get(android + "roundIcon") == "@mipmap/ic_launcher_round"
print("Android icons passed: approved PNG parity, dimensions, adaptive/themed layers, manifest and legacy round fallback.")
PYTHON

if [ "$fail" -ne 0 ]; then
  echo "Validation FAILED"
  exit 2
fi
echo "Validation finished."
