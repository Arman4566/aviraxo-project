import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

/// App-wide snackbar access, so repositories and screens can show server errors without a BuildContext.
class AppMessenger {
  static final GlobalKey<ScaffoldMessengerState> key = GlobalKey<ScaffoldMessengerState>();

  static void error(Object e) => _show(_text(e), isError: true);
  static void info(String m) => _show(m);

  static String _text(Object e) {
    final s = e.toString();
    return s.startsWith('Exception: ') ? s.substring(11) : s;
  }

  static void _show(String m, {bool isError = false}) {
    final s = key.currentState;
    if (s == null) return;
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? const Color(0xFFB3261E) : null,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
