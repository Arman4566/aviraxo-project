import 'package:flutter/material.dart';

/// Aviraxo palette with two modes (light / dark) and a frosted-glass look.
///
/// Colours that change with the mode are getters, so they always return the value for the mode that is active
/// ([dark] is set by the app root before anything is built). Because they are not compile-time constants, widgets that
/// use them cannot be `const`; the root rebuilds the whole tree when the mode changes, so every screen follows.
class GPColors {
  /// Set by the app root. Do not set this from screens; use AppPrefs.I.setThemeMode instead.
  static bool dark = false;

  // Brand
  static Color get primary => dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);       // links, focus, selected states (design guide: brand-primary-action)
  static Color get primaryDeep => dark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);   // emphasis text
  static Color get tint => dark ? const Color(0x403B82F6) : const Color(0x1F2563EB);          // selected cards, chips (see-through wash)
  static const Color onPrimary = Colors.white;         // text/icons placed on primary
  static const Color accent = Color(0xFF14B8A6);       // teal: second series in charts, highlights
  static const Color commit = Color(0xFF059669);       // the one terminal action on a screen (Save, Charge, Collect)
  static const Color sandbox = Color(0xFF7C3AED);      // practice / test mode only
  static const Color highlight = Color(0xFFFEF08A);    // search match highlight (use with dark text)
  static const Color white = Colors.white;

  // Neutrals (text, lines, glass surfaces)
  static Color get ink => dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);           // main text
  static Color get ink2 => dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);          // secondary text
  static Color get line => dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);         // dividers and thin borders
  static Color get surface => dark ? const Color(0xF21E293B) : const Color(0xF2FFFFFF);       // cards: near-solid so numbers stay crisp
  static Color get bg => dark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC);            // base colour behind the glass

  // Glass details
  static Color get glassEdge => dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);     // bright rim of a glass panel
  static Color get glassSolid => dark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);    // where it must be opaque (menus)
  static Color get glassShadow => dark ? const Color(0x66000000) : const Color(0x140F172A);

  // Meaning (readable in both modes)
  static const Color success = Color(0xFF059669);      // money in, paid, verified (emerald)
  static const Color danger = Color(0xFFDC2626);       // void, out of stock, errors (hazard red)
  static const Color warning = Color(0xFFD97706);      // due soon, low stock (amber)
  static const Color info = Color(0xFF0A8FD6);         // neutral information

  // Chart series (colour-blind friendly order)
  static const List<Color> series = [
    Color(0xFF2563EB), Color(0xFF14B8A6), Color(0xFFD97706), Color(0xFFEC4899), Color(0xFF0EA5E9), Color(0xFF84CC16),
  ];
}
