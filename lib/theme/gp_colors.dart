import 'package:flutter/material.dart';

/// Galla Pro palette. Indigo for actions, emerald for money-in, soft cool-grey backgrounds.
/// Every screen reads colours from here, so changing a value re-skins the whole app.
class GPColors {
  // Brand
  static const Color primary = Color(0xFF4F46E5);      // indigo: buttons, selected states, app bar
  static const Color primaryDeep = Color(0xFF3730A3);  // pressed / emphasis text
  static const Color tint = Color(0xFFEEF2FF);         // light indigo wash for selected cards and chips
  static const Color onPrimary = Colors.white;         // text/icons placed on primary
  static const Color accent = Color(0xFF14B8A6);       // teal: second series in charts, highlights
  static const Color white = Colors.white;

  // Neutrals
  static const Color ink = Color(0xFF0F172A);          // main text
  static const Color ink2 = Color(0xFF64748B);         // secondary text
  static const Color line = Color(0xFFE2E8F0);         // borders and dividers
  static const Color surface = Color(0xFFFFFFFF);      // cards
  static const Color bg = Color(0xFFF6F7FB);           // app background

  // Meaning
  static const Color success = Color(0xFF059669);      // money in, paid, healthy
  static const Color danger = Color(0xFFDC2626);       // overdue, out of stock, errors
  static const Color warning = Color(0xFFD97706);      // due soon, low stock
  static const Color info = Color(0xFF0284C7);         // neutral information

  // Chart series (colour-blind friendly order)
  static const List<Color> series = [
    Color(0xFF4F46E5), Color(0xFF14B8A6), Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF0EA5E9), Color(0xFF84CC16),
  ];

  // Dark mode surfaces
  static const Color darkBg = Color(0xFF0B1020);
  static const Color darkSurface = Color(0xFF151B2E);
  static const Color darkLine = Color(0xFF2A3350);
}
