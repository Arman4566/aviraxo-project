import 'package:flutter/material.dart';
import 'gp_colors.dart';

class AppTheme {
  static const _text = TextTheme(
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: GPColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: GPColors.primary,
      onPrimary: GPColors.onPrimary,
      secondary: GPColors.accent,
      surface: GPColors.surface,
      error: GPColors.danger,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: GPColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: GPColors.bg,
      textTheme: _text,
      appBarTheme: const AppBarTheme(
        backgroundColor: GPColors.surface,
        foregroundColor: GPColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(color: GPColors.ink, fontSize: 18, fontWeight: FontWeight.w800),
      ),
      // Buttons always get white text on indigo, so a screen that only sets backgroundColor stays readable.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GPColors.primary,
          foregroundColor: GPColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GPColors.primary,
          foregroundColor: GPColors.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GPColors.primary,
          side: const BorderSide(color: GPColors.line),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: GPColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GPColors.primary,
        foregroundColor: GPColors.onPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: GPColors.surface,
        selectedColor: GPColors.tint,
        side: const BorderSide(color: GPColors.line),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: GPColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: GPColors.primary,
        unselectedLabelColor: GPColors.ink2,
        indicatorColor: GPColors.primary,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
      ),
      dividerTheme: const DividerThemeData(color: GPColors.line, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GPColors.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GPColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: GPColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: GPColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GPColors.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GPColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Dark theme. Screens that read colours from Theme.of(context) follow it automatically;
  /// older screens that use GPColors constants directly keep their light look until they are migrated.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: GPColors.primary,
      brightness: Brightness.dark,
    ).copyWith(primary: const Color(0xFF818CF8), onPrimary: GPColors.darkBg, surface: GPColors.darkSurface);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: GPColors.darkLine),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: GPColors.darkBg,
      textTheme: _text,
      appBarTheme: const AppBarTheme(backgroundColor: GPColors.darkSurface, elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GPColors.darkSurface,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: GPColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: GPColors.darkLine)),
      ),
    );
  }
}
