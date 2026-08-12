# KiwiShare UI Design Guidelines

**Version:** 1.1 (Approved baseline)  
**Team:** Five Guys  
**Product:** KiwiShare  
**Last updated:** 12 August 2026  
**Visual source:** *KiwiShare Elevator Pitch – Assignment 1*

## 1. Purpose

This document defines the shared visual language for the KiwiShare mobile application. It translates the established presentation style into reusable UI rules so that screens created by different team members remain consistent, accessible, and recognisably KiwiShare.

The design should feel:

- **Trustworthy:** safe enough for local second-hand transactions.
- **Local:** friendly and relevant to communities in Aotearoa New Zealand.
- **Sustainable:** calm, natural colours without appearing overly corporate.
- **Simple:** clear flows for listing, finding, messaging, and completing a trade.

## 2. Design principles

1. **Trust before decoration.** Important actions, identity, payment, location, and transaction status must always be clear.
2. **Simple by default.** Each screen should have one primary task and one visually dominant action.
3. **Consistent across the journey.** Reuse the same colours, spacing, type scale, and component states.
4. **Accessible to everyone.** Meet WCAG AA contrast, support text scaling, and never rely on colour alone.
5. **Local and human.** Use friendly NZ English, real product photography, and community-focused language.

## 3. Colour system

### 3.1 Core brand colours

| Token | Hex | Recommended use |
|---|---:|---|
| `brandPrimary` | `#064B3A` | Primary buttons, selected navigation, key headings, trusted brand moments |
| `brandPrimaryAlt` | `#0B5B47` | Hover/secondary brand emphasis and large headings |
| `brandSecondary` | `#4E8878` | Secondary graphics, icons, decorative elements, non-text emphasis |
| `brandAccent` | `#D99713` | Progress markers, highlights, badges, and small decorative accents |
| `brandPrimaryContainer` | `#DCEBCB` | Selected cards, success-adjacent surfaces, subtle brand backgrounds |
| `brandSecondaryContainer` | `#DDE9E4` | Secondary panels and calm informational surfaces |

### 3.2 Neutral and surface colours

| Token | Hex | Recommended use |
|---|---:|---|
| `background` | `#FBFAF6` | Default app background |
| `surface` | `#FFFFFF` | Cards, bottom sheets, dialogs, and input surfaces |
| `surfaceMuted` | `#EFF4E9` | Subtle grouped sections and sustainability messages |
| `textPrimary` | `#17221E` | Main body text and high-priority information |
| `textBrand` | `#064B3A` | Brand headings and active labels |
| `textSecondary` | `#5F6D66` | Supporting text, metadata, timestamps, and helper copy |
| `border` | `#BFD5CD` | Input, card, and section borders |
| `divider` | `#DCEBCB` | Dividers and separators |
| `disabled` | `#999999` | Disabled text and icons only |

### 3.3 Semantic colours

| Token | Hex | Container | Use |
|---|---:|---:|---|
| `success` | `#2E7D32` | `#E8F5E9` | Completed trade, verified state, successful action |
| `warning` | `#6B4A00` | `#FFF2CC` | Caution, incomplete steps, pending verification |
| `error` | `#B3261E` | `#F9DEDC` | Failed action, destructive action, validation error |
| `info` | `#3F6FD9` | `#E8EEFF` | Neutral information, help, and system notices |

### 3.4 Colour usage rules

- Use `brandPrimary` for the single primary action on a screen.
- Use `brandAccent` sparingly. It does **not** have sufficient contrast for small text on a light background.
- Use dark text such as `textPrimary` or `warning` on `#FFF2CC` warning surfaces.
- Do not place white text on `brandAccent` or `brandSecondary` for normal-size copy.
- Use `textSecondary` only for supporting information, never for essential actions.
- Avoid using more than one strong accent colour in the same component.
- Status must be communicated with an icon and/or label as well as colour.

### 3.5 Confirmed contrast pairs

| Foreground | Background | Contrast ratio | Result |
|---|---|---:|---|
| `#064B3A` | `#FBFAF6` | 9.69:1 | AAA |
| `#FFFFFF` | `#064B3A` | 10.12:1 | AAA |
| `#17221E` | `#FBFAF6` | 15.66:1 | AAA |
| `#5F6D66` | `#FBFAF6` | 5.20:1 | AA |
| `#D99713` | `#FBFAF6` | 2.40:1 | Decorative/large graphics only |

## 4. Typography

### 4.1 Font family

- **Mobile UI:** `Inter`, with the platform system font as fallback.
- **Presentation and marketing material:** `Arial`, matching the existing pitch deck.

Do not set Arial as the Flutter app font. Arial is not consistently bundled across Android and iOS. Inter provides a similar clean, modern appearance and predictable cross-platform rendering.

### 4.2 Mobile type scale

| Style | Size / line height | Weight | Use |
|---|---:|---:|---|
| `displayLarge` | 32 / 40 | 700 | Short onboarding or campaign statement |
| `headlineLarge` | 24 / 32 | 700 | Screen title |
| `headlineMedium` | 20 / 28 | 700 | Major section heading |
| `titleMedium` | 16 / 24 | 600 | Card title, dialog title, list item title |
| `bodyLarge` | 16 / 24 | 400 | Default readable body copy |
| `bodyMedium` | 14 / 20 | 400 | Supporting copy and metadata |
| `labelLarge` | 14 / 20 | 600 | Buttons, tabs, filters, and input labels |
| `labelSmall` | 12 / 16 | 500 | Captions and low-priority metadata |

Typography rules:

- Use sentence case, not ALL CAPS, for normal UI labels.
- Limit each screen to three clear text levels where possible.
- Body text should normally be at least 14 px; use 16 px for longer reading.
- Allow system text scaling without clipping or hiding actions.
- Use bold weight for hierarchy, not for whole paragraphs.

## 5. Spacing and layout

KiwiShare uses an **8-point spacing system**, with a 4-point half-step for fine alignment.

| Token | Value | Typical use |
|---|---:|---|
| `space1` | 4 | Icon/text micro-gap |
| `space2` | 8 | Closely related elements |
| `space3` | 12 | Internal compact padding |
| `space4` | 16 | Default screen and card padding |
| `space6` | 24 | Section separation |
| `space8` | 32 | Major vertical break |
| `space12` | 48 | Large hero or onboarding separation |

Layout rules:

- Use 16 px horizontal screen padding on mobile.
- Use 24 px between major sections.
- Align text and components to a shared left edge.
- Keep a minimum touch target of 48 × 48 px.
- Use responsive constraints rather than fixed screen widths.
- Keep primary actions visible without requiring unnecessary scrolling.

## 6. Shape, radius, border, and elevation

| Token | Value | Use |
|---|---:|---|
| `radiusSmall` | 8 | Chips, compact controls, thumbnails |
| `radiusMedium` | 12 | Inputs, buttons, product cards |
| `radiusLarge` | 16 | Dialogs, sheets, large feature cards |
| `radiusFull` | 999 | Circular buttons, avatars, pill badges |

- Standard border: 1 px `border`.
- Focused input border: 2 px `brandPrimary`.
- Use low elevation: 0 for flat content, 1 for cards, and 2–3 for temporary overlays.
- Prefer borders and surface colour changes over heavy drop shadows.
- Do not mix several corner-radius styles within one component family.

## 7. Core component rules

### 7.1 Buttons

**Primary button**

- Background: `brandPrimary`
- Label/icon: white
- Minimum height: 48 px
- Radius: 12 px
- Use once per screen or section whenever possible

**Secondary button**

- Background: transparent or `surface`
- Border and label: `brandPrimary`
- Same height and radius as the primary button

**Text button**

- Label: `brandPrimary`
- No container unless required for selection or focus

**Destructive button**

- Use `error` only for actions such as delete listing, block user, or cancel a confirmed trade.
- Require confirmation when the action is difficult to reverse.

All buttons require default, pressed, focused, disabled, and loading states.

### 7.2 Inputs and search

- Minimum height: 48 px.
- Background: `surface`.
- Default border: 1 px `border`.
- Focus border: 2 px `brandPrimary`.
- Error border and helper text: `error`.
- Labels remain visible; do not rely only on placeholder text.
- Search should include a clear action and preserve the user's query.

### 7.3 Product cards

- Surface: white or `surface`.
- Radius: 12 px.
- Product image ratio: 4:3 where practical.
- Show title, price, approximate location, seller/verification cue, and favourite action.
- Use one-line truncation for titles and maintain consistent card height in grids.
- Do not expose exact private addresses in browse views.

### 7.4 Chips and badges

- Use chips for categories, filters, suggested messages, and status.
- Default: `surface` with `border`.
- Selected: `brandPrimaryContainer` with `brandPrimary` text/icon.
- Keep labels short and avoid wrapping.
- Do not represent critical status with colour alone.

### 7.5 Navigation

- Use four or five top-level destinations at most.
- Active item: `brandPrimary` icon and label.
- Inactive item: `textSecondary`.
- Keep icon meanings and destination order stable across screens.
- A central create/list action may use a filled circular `brandPrimary` button.

### 7.6 Feedback and transaction states

- Provide immediate feedback after save, reserve, send, scan, pay, and confirm actions.
- Use a progress indicator for operations longer than one second.
- Preserve the user's content after a recoverable error.
- Confirmation screens should state what happened and what the user can do next.

## 8. Icons and imagery

- Use one icon family consistently, preferably Material Symbols Rounded.
- Default icon size: 24 px; compact icon: 20 px.
- Use outlined icons for inactive states and filled icons for active states where available.
- Pair unfamiliar or high-risk icons with a text label.
- Use real listing photography for marketplace content; do not use generated images as product evidence.
- Use illustration only for onboarding, empty states, education, and brand storytelling.
- Keep the kiwi mark and logo proportions unchanged and provide clear space around the logo equal to at least the height of the kiwi's eye/head detail.

## 9. Content style

- Use clear, friendly NZ English.
- Prefer direct action labels: **List an item**, **Message seller**, **Reserve item**, **Confirm trade**.
- Avoid technical language such as “execute transaction” or “invoke function” in user-facing copy.
- Explain why location, camera, or notification permission is needed before requesting it.
- Use “Aotearoa New Zealand” on first formal mention; use “Aotearoa” or “New Zealand” naturally afterward.
- Error messages should explain the problem and provide the next action.

## 10. Accessibility requirements

- Meet WCAG 2.2 AA: 4.5:1 for normal text and 3:1 for large text and meaningful UI graphics.
- Support screen readers with semantic labels and logical reading order.
- Support keyboard focus where applicable and visible focus indicators.
- Minimum interactive area: 48 × 48 px.
- Do not use colour, motion, or iconography as the only method of communication.
- Respect reduced-motion settings for non-essential animation.
- Test at 200% text scaling for clipping and overflow.
- Provide alternatives to map-only or QR-only interactions.

## 11. Flutter design tokens

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brandPrimary = Color(0xFF064B3A);
  static const brandPrimaryAlt = Color(0xFF0B5B47);
  static const brandSecondary = Color(0xFF4E8878);
  static const brandAccent = Color(0xFFD99713);
  static const brandPrimaryContainer = Color(0xFFDCEBCB);
  static const brandSecondaryContainer = Color(0xFFDDE9E4);

  static const background = Color(0xFFFBFAF6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFF4E9);
  static const textPrimary = Color(0xFF17221E);
  static const textSecondary = Color(0xFF5F6D66);
  static const border = Color(0xFFBFD5CD);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFF6B4A00);
  static const error = Color(0xFFB3261E);
  static const info = Color(0xFF3F6FD9);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
}
```

Recommended base colour scheme:

```dart
const kiwiShareColorScheme = ColorScheme.light(
  primary: AppColors.brandPrimary,
  onPrimary: Colors.white,
  primaryContainer: AppColors.brandPrimaryContainer,
  onPrimaryContainer: AppColors.textPrimary,
  secondary: AppColors.brandPrimaryAlt,
  onSecondary: Colors.white,
  surface: AppColors.surface,
  onSurface: AppColors.textPrimary,
  error: AppColors.error,
  onError: Colors.white,
  outline: AppColors.border,
);
```

The team should define colours and text styles once in the app theme. Feature code must reference shared tokens rather than adding new hexadecimal values or one-off `TextStyle` definitions.

## 12. Team review checklist

Before merging a UI pull request, confirm:

- [ ] Shared colour and typography tokens are used.
- [ ] The screen has one clear primary action.
- [ ] Spacing follows the 8-point system.
- [ ] Interactive targets are at least 48 × 48 px.
- [ ] Loading, empty, error, disabled, and success states are handled.
- [ ] Text remains readable when enlarged.
- [ ] Colour contrast meets AA and meaning is not colour-only.
- [ ] No exact private location is exposed unnecessarily.
- [ ] Naming and wording match the rest of the app.
- [ ] Widget tests or golden tests cover important reusable components.

## 13. Governance

- Treat this file as the single source of truth for shared UI decisions.
- Discuss new tokens or component variants with the team before introducing them.
- Update this document in the same pull request as any approved design-system change.
- Prefer extending an existing component over creating a visually similar duplicate.
