import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/glass.dart';
import 'gp_colors.dart';

/// One theme builder for both modes. It reads [GPColors] (which follow `GPColors.dark`), so the app root sets
/// `GPColors.dark` first and then calls [AppTheme.build].
///
/// Look: screens are transparent so the glass backdrop shows through; cards, bars and fields are see-through
/// "glass" with a thin bright rim; sheets, dialogs and the drawer blur what is behind them.
class AppTheme {
  static const _text = TextTheme(
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  static ThemeData build() {
    final dark = GPColors.dark;
    final brightness = dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: brightness).copyWith(
      primary: GPColors.primary,
      onPrimary: GPColors.onPrimary,
      secondary: GPColors.accent,
      surface: GPColors.glassSolid, // opaque on purpose: menus and pickers use it
      onSurface: GPColors.ink,
      onSurfaceVariant: GPColors.ink2,
      outline: GPColors.line,
      outlineVariant: GPColors.line,
      error: GPColors.danger,
    );

    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
    final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final overlay = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent, // the glass backdrop is painted by every page route
      canvasColor: GPColors.glassSolid,
      textTheme: _text.apply(bodyColor: GPColors.ink, displayColor: GPColors.ink),
      iconTheme: IconThemeData(color: GPColors.ink),
      dividerColor: GPColors.line,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: GlassPageTransitions(),
        TargetPlatform.iOS: GlassPageTransitions(),
        TargetPlatform.windows: GlassPageTransitions(),
        TargetPlatform.macOS: GlassPageTransitions(),
        TargetPlatform.linux: GlassPageTransitions(),
        TargetPlatform.fuchsia: GlassPageTransitions(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: GPColors.surface,
        foregroundColor: GPColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: GPColors.glassEdge)),
        centerTitle: false,
        systemOverlayStyle: overlay,
        titleTextStyle: TextStyle(color: GPColors.ink, fontSize: 18, fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: GPColors.ink),
        actionsIconTheme: IconThemeData(color: GPColors.ink),
      ),
      // Buttons always get white text on indigo, so a screen that only sets backgroundColor stays readable.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GPColors.primary,
          foregroundColor: GPColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: shape14,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GPColors.primary,
          foregroundColor: GPColors.onPrimary,
          minimumSize: const Size(64, 48),
          shape: shape14,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? GPColors.primaryDeep : GPColors.primary,
          backgroundColor: GPColors.surface,
          side: BorderSide(color: GPColors.glassEdge),
          minimumSize: const Size(64, 48),
          shape: shape14,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: dark ? GPColors.primaryDeep : GPColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: GPColors.primary, foregroundColor: GPColors.onPrimary, elevation: 3),
      chipTheme: ChipThemeData(
        backgroundColor: GPColors.surface,
        selectedColor: GPColors.tint,
        side: BorderSide(color: GPColors.glassEdge),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: GPColors.ink),
        shape: const StadiumBorder(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GPColors.primary : GPColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GPColors.onPrimary : GPColors.ink),
          side: WidgetStatePropertyAll(BorderSide(color: GPColors.glassEdge)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: dark ? GPColors.primaryDeep : GPColors.primary,
        unselectedLabelColor: GPColors.ink2,
        indicatorColor: GPColors.primary,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      dividerTheme: DividerThemeData(color: GPColors.line, thickness: 1),
      listTileTheme: ListTileThemeData(iconColor: GPColors.ink2, textColor: GPColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GPColors.surface,
        hintStyle: TextStyle(color: GPColors.ink2.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: GPColors.ink2),
        border: border(GPColors.glassEdge),
        enabledBorder: border(GPColors.glassEdge),
        focusedBorder: border(GPColors.primary, 1.6),
        errorBorder: border(GPColors.danger),
        focusedErrorBorder: border(GPColors.danger, 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: GPColors.surface,
        shadowColor: GPColors.glassShadow,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: GPColors.glassEdge)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GPColors.glassSolid.withValues(alpha: dark ? 0.92 : 0.94),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: BorderSide(color: GPColors.glassEdge)),
        titleTextStyle: TextStyle(color: GPColors.ink, fontSize: 18, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: GPColors.ink2, fontSize: 14.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0),
      drawerTheme: DrawerThemeData(
        backgroundColor: GPColors.glassSolid.withValues(alpha: dark ? 0.82 : 0.86),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: GPColors.glassSolid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: GPColors.glassEdge)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: GPColors.tint,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: GPColors.surface,
        selectedItemColor: dark ? GPColors.primaryDeep : GPColors.primary,
        unselectedItemColor: GPColors.ink2,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : (dark ? const Color(0xFFCBD5E1) : Colors.white)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? GPColors.primary : (dark ? const Color(0x55FFFFFF) : const Color(0x33475569))),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: GPColors.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xF22B3560) : const Color(0xF20F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      datePickerTheme: DatePickerThemeData(backgroundColor: GPColors.glassSolid, surfaceTintColor: Colors.transparent),
      timePickerTheme: TimePickerThemeData(backgroundColor: GPColors.glassSolid),
    );
  }
}
