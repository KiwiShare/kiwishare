# KiwiShare App Icon Asset Pack

**Version:** 1.0  
**Status:** Production-ready  
**Platforms:** iOS and Android  
**Related work item:** GitHub Issue #17 — App icon placement

## 1. Overview

This package contains the approved KiwiShare application icon and all production assets required for the current Flutter iOS and Android projects.

The mark combines three ideas:

- a **kiwi bird**, representing Aotearoa New Zealand;
- a **circular arrow**, representing sharing, reuse, and the circular economy; and
- a **leaf**, representing sustainability.

The approved geometry has been preserved. Production work was limited to image cleanup, platform-safe scaling, colour separation, appearance variants, and export sizing.

## 2. Brand palette

| Token | Hex | Intended use |
|---|---:|---|
| Kiwi Green | `#076348` | Primary mark on light surfaces |
| Deep Forest | `#0D2620` | Dark icon background |
| Warm Cream | `#FAF5EA` | Default light icon background |
| Soft Ivory | `#E2EDE1` | Mark on dark surfaces |

The icon remains recognisable without colour, so its meaning does not depend on green perception alone. Light and dark variants use the same silhouette and maintain strong luminance contrast.

## 3. Package structure

```text
kiwishare-app-icon-v1.0/
├── master/                         High-resolution production masters
├── ios/
│   ├── modern/                     1024 px default, dark, and tinted sources
│   └── legacy/                     Current AppIcon.appiconset PNG exports
├── android/
│   ├── adaptive/                   Foreground, background, monochrome, and XML
│   ├── adaptive-dark-reference/    Optional dark appearance reference
│   ├── legacy/                     mdpi–xxxhdpi launcher PNGs
│   └── play-store/                 512 px store artwork
├── palette/                        Machine-readable colour tokens
├── previews/                       Visual QA sheets
├── ASSET-MANIFEST.md               Detailed asset inventory
├── README.md                       English integration guide
└── README.zh-CN.md                 Chinese reference guide
```

## 4. Required deliverables

| Platform target | Required asset | Location in this package |
|---|---|---|
| iOS default/light | Opaque 1024 × 1024 PNG | `ios/modern/` |
| iOS dark appearance | Opaque 1024 × 1024 PNG | `ios/modern/` |
| iOS tinted appearance | Tint-compatible source | `ios/modern/` |
| Current iOS catalogue | All PNG sizes named by the existing catalogue | `ios/legacy/` |
| Android adaptive foreground | Transparent foreground layer | `android/adaptive/` |
| Android adaptive background | Solid background resource | `android/adaptive/` |
| Android themed icon | Single-colour monochrome mask | `android/adaptive/` |
| Legacy Android | 48, 72, 96, 144, and 192 px PNGs | `android/legacy/` |
| Google Play | 512 × 512 PNG | `android/play-store/` |

See `ASSET-MANIFEST.md` for exact filenames, dimensions, transparency rules, and intended destinations.

## 5. iOS installation

### 5.1 Current repository asset catalogue

Replace the matching image files in:

```text
mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

with the files from:

```text
ios/legacy/
```

Keep the repository's existing `Contents.json` unless the asset catalogue is intentionally migrated. Every filename referenced by `Contents.json` must remain present.

### 5.2 Modern appearance variants

When the Xcode asset catalogue supports appearance variants, assign the 1024 px sources from `ios/modern/` to the appropriate **Default**, **Dark**, and **Tinted** slots.

Important rules:

- iOS icon artwork must be square and opaque.
- Do not add rounded corners; the system applies the final mask.
- Do not add an external drop shadow or a transparent outer margin.
- Confirm that the bird, circular arrow, leaf, beak, feet, and eye remain visible at small sizes.

## 6. Android installation

### 6.1 Legacy launcher icons

Copy each density-specific PNG from `android/legacy/` to the matching Flutter Android resource directory and retain the filename `ic_launcher.png`:

| Density | Pixel size | Destination |
|---|---:|---|
| mdpi | 48 × 48 | `mobile/android/app/src/main/res/mipmap-mdpi/` |
| hdpi | 72 × 72 | `mobile/android/app/src/main/res/mipmap-hdpi/` |
| xhdpi | 96 × 96 | `mobile/android/app/src/main/res/mipmap-xhdpi/` |
| xxhdpi | 144 × 144 | `mobile/android/app/src/main/res/mipmap-xxhdpi/` |
| xxxhdpi | 192 × 192 | `mobile/android/app/src/main/res/mipmap-xxxhdpi/` |

### 6.2 Adaptive and themed icons

Use the resources in `android/adaptive/` to configure:

- a transparent foreground layer;
- a solid background colour or background resource;
- an adaptive-icon XML resource; and
- a monochrome layer for Android 13+ themed icons.

The adaptive foreground is intentionally scaled more conservatively than the iOS artwork. Do not enlarge it without testing every launcher mask; the entire symbol must remain inside the adaptive safe zone.

The monochrome image is a mask, not a final coloured icon. Compatible Android launchers apply the user's system theme colour at runtime.

## 7. Verification checklist

Complete the following checks before opening the pull request:

- [ ] All files listed in `ASSET-MANIFEST.md` exist at the expected paths.
- [ ] iOS artwork is square, opaque, and has no pre-rendered rounded corners.
- [ ] The existing iOS `Contents.json` references valid filenames.
- [ ] Android legacy PNGs have the correct dimensions for every density.
- [ ] Android adaptive foreground transparency is preserved.
- [ ] The adaptive icon renders correctly with circle, squircle, rounded-square, and teardrop masks.
- [ ] The themed icon remains legible when recoloured by Android.
- [ ] The icon is recognisable at 48 px, not only at 512 or 1024 px.
- [ ] The icon is checked on at least one light and one dark home-screen wallpaper.
- [ ] The app builds successfully for both platforms after asset replacement.
- [ ] A physical device or platform simulator shows the expected launcher icon.

Recommended project checks:

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

Run the platform build commands used by the repository's CI or release workflow before merging.

## 8. Accessibility and inclusive design

- The symbol must remain identifiable in monochrome and grayscale.
- Meaning must not rely on colour alone.
- Strong figure-to-background contrast must be maintained in both light and dark variants.
- Fine detail, thin strokes, text, and low-contrast decoration must not be introduced.
- The product name, **KiwiShare**, is the accessible spoken label; essential text must not be embedded in the icon.
- Do not replace the icon with an emoji or culturally ambiguous symbol.

These rules support users with low vision, colour-vision differences, high-contrast settings, themed icons, and small display sizes.

## 9. Usage restrictions

Do not:

- alter the kiwi silhouette, circular arrow, or leaf geometry;
- stretch, skew, rotate, crop, or independently reposition parts of the mark;
- change the approved colour values without a documented design decision;
- add text, gradients, photographic textures, or additional symbols;
- pre-round icon corners;
- use low-resolution exports as new master files; or
- edit generated platform assets without updating the master and regenerating the complete set.

## 10. Source of truth and maintenance

The canonical source for this release is the lossless 4096 × 4096 PNG master in `master/`, derived from the approved KiwiShare artwork. The platform exports are generated deliverables and should not become independent design sources.

If the mark changes:

1. update the canonical master;
2. regenerate every iOS and Android variant;
3. update `ASSET-MANIFEST.md` if filenames, sizes, or destinations change;
4. repeat the verification checklist; and
5. release the package under a new version number.

A true vector redraw may be added later for large-format or print use, but it is not required for the current mobile application delivery.

## 11. Pull request scope

The app-icon pull request should contain only the icon assets and any configuration strictly required to reference them. Avoid unrelated application-code changes. Reference GitHub Issue #17 in the pull request description and attach light, dark, and Android mask previews as review evidence.
