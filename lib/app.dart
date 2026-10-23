import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/messenger.dart';
import 'core/prefs.dart';
import 'theme/app_theme.dart';
import 'theme/gp_colors.dart';
import 'auth/auth_gate.dart';

class GallaProApp extends StatefulWidget {
  const GallaProApp({super.key});

  @override
  State<GallaProApp> createState() => _GallaProAppState();
}

class _GallaProAppState extends State<GallaProApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppPrefs.I.language.addListener(_changed);
    AppPrefs.I.themeMode.addListener(_changed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppPrefs.I.language.removeListener(_changed);
    AppPrefs.I.themeMode.removeListener(_changed);
    super.dispose();
  }

  /// Phone switched between light and dark while the app is set to "System".
  @override
  void didChangePlatformBrightness() {
    if (AppPrefs.I.themeMode.value == ThemeMode.system) _changed();
  }

  bool get _isDark {
    final mode = AppPrefs.I.themeMode.value;
    if (mode == ThemeMode.system) return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    return mode == ThemeMode.dark;
  }

  /// Language or theme changed: rebuild the app, then force every widget (including `const` ones, which Flutter
  /// would normally skip) to rebuild so all text and colours update without losing the current screen.
  void _changed() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      if (mounted) (context as Element).visitChildren(mark);
    });
  }

  @override
  Widget build(BuildContext context) {
    GPColors.dark = _isDark; // must be set before the theme and any screen reads GPColors
    final lang = AppPrefs.I.language.value;
    return MaterialApp(
      title: 'Galla Pro',
      scaffoldMessengerKey: AppMessenger.key,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      themeMode: ThemeMode.light, // the single theme above already encodes light or dark
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}
