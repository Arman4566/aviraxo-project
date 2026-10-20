import 'package:flutter/material.dart';

import 'core/messenger.dart';
import 'core/prefs.dart';
import 'theme/app_theme.dart';
import 'auth/auth_gate.dart';

class GallaProApp extends StatelessWidget {
  const GallaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole app when the language or theme changes, so the switch is instant.
    return ValueListenableBuilder<String>(
      valueListenable: AppPrefs.I.language,
      builder: (_, lang, __) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppPrefs.I.themeMode,
        builder: (_, mode, __) => MaterialApp(
          key: ValueKey('app-$lang'),
          title: 'Galla Pro',
          scaffoldMessengerKey: AppMessenger.key,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          locale: Locale(lang),
          home: const AuthGate(),
        ),
      ),
    );
  }
}
