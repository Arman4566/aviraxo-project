import 'package:flutter/material.dart';

/// Galla Pro palette with two modes (light / dark) and a frosted-glass look.
///
/// Colours that change with the mode are getters, so they always return the value for the mode that is active
/// ([dark] is set by the app root before anything is built). Because they are not compile-time constants, widgets that
/// use them cannot be `const`; the root rebuilds the whole tree when the mode changes, so every screen follows.
class GPColors {
  /// Set by the app root. Do not set this from screens; use AppPrefs.I.setThemeMode instead.
  static bool dark = false;

  // Brand
  static Color get primary => dark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5);       // buttons, selected states
  static Color get primaryDeep => dark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3);   // emphasis text
  static Color get tint => dark ? const Color(0x336366F1) : const Color(0x1F4F46E5);          // selected cards, chips (see-through wash)
  static const Color onPrimary = Colors.white;         // text/icons placed on primary
  static const Color accent = Color(0xFF14B8A6);       // teal: second series in charts, highlights
  static const Color white = Colors.white;

  // Neutrals (text, lines, glass surfaces)
  static Color get ink => dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);           // main text
  static Color get ink2 => dark ? const Color(0xFFA3AEC4) : const Color(0xFF5B6B84);          // secondary text
  static Color get line => dark ? const Color(0x2EFFFFFF) : const Color(0x1F0F172A);         // dividers and thin borders
  static Color get surface => dark ? const Color(0x991E2748) : const Color(0xB8FFFFFF);       // glass cards (see-through)
  static Color get bg => dark ? const Color(0xFF0B1020) : const Color(0xFFF3F4FA);            // base colour behind the glass

  // Glass details
  static Color get glassEdge => dark ? const Color(0x33FFFFFF) : const Color(0xCCFFFFFF);     // bright rim of a glass panel
  static Color get glassSolid => dark ? const Color(0xFF1A2240) : const Color(0xFFFFFFFF);    // where it must be opaque (menus)
  static Color get glassShadow => dark ? const Color(0x66000000) : const Color(0x1A1E2A5A);

  // Meaning (readable in both modes)
  static const Color success = Color(0xFF059669);      // money in, paid, healthy
  static const Color danger = Color(0xFFDC2626);       // overdue, out of stock, errors
  static const Color warning = Color(0xFFD97706);      // due soon, low stock
  static const Color info = Color(0xFF0284C7);         // neutral information

  // Chart series (colour-blind friendly order)
  static const List<Color> series = [
    Color(0xFF4F46E5), Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF0EA5E9), Color(0xFF84CC16),
  ];
}
