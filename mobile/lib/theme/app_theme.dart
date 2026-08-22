import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const textBrand = Color(0xFF064B3A);
  static const textSecondary = Color(0xFF5F6D66);
  static const border = Color(0xFFBFD5CD);
  static const divider = Color(0xFFDCEBCB);
  static const disabled = Color(0xFF999999);

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
  static const xxxl = 48.0;
}

abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const full = 999.0;
}

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

// Keep the brand recognisable in dark mode, but use proper dark surfaces and
// high-contrast text. Screens should read colours from Theme.of(context)
// rather than hard-coding the light palette.
const kiwiShareDarkColorScheme = ColorScheme.dark(
  primary: Color(0xFF92D4B3),
  onPrimary: Color(0xFF003827),
  primaryContainer: Color(0xFF0A5941),
  onPrimaryContainer: Color(0xFFD6F6E3),
  secondary: Color(0xFFAFCFC0),
  onSecondary: Color(0xFF19362B),
  surface: Color(0xFF101B17),
  onSurface: Color(0xFFE1EAE4),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  outline: Color(0xFF8DA79A),
);

ThemeData buildKiwiShareTheme() {
  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: kiwiShareColorScheme,
    scaffoldBackgroundColor: AppColors.background,
  );
  final baseTextTheme = GoogleFonts.interTextTheme(baseTheme.textTheme);

  return baseTheme.copyWith(
    textTheme: baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: 32,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    ),
    dividerColor: AppColors.divider,
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: AppColors.brandPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
    ),
  );
}

ThemeData buildKiwiShareDarkTheme() {
  final baseTheme = ThemeData(
    useMaterial3: true,
    colorScheme: kiwiShareDarkColorScheme,
    scaffoldBackgroundColor: const Color(0xFF0B120F),
  );
  final baseTextTheme = GoogleFonts.interTextTheme(baseTheme.textTheme);

  return baseTheme.copyWith(
    textTheme: baseTextTheme.apply(
      bodyColor: kiwiShareDarkColorScheme.onSurface,
      displayColor: kiwiShareDarkColorScheme.onSurface,
    ),
    dividerColor: const Color(0xFF2B3B33),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF16231D),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: Color(0xFF496358)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: Color(0xFF496358)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        borderSide: BorderSide(color: Color(0xFF92D4B3), width: 2),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF16231D),
      selectedItemColor: Color(0xFF92D4B3),
      unselectedItemColor: Color(0xFFB6C6BD),
    ),
  );
}
