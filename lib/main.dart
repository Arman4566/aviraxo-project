import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/outbox.dart';
import 'core/prefs.dart';
import 'data/local_db.dart';
import 'firebase_options.dart';

/// Shows the real startup error on screen instead of a blank page, so it can be read and reported.
class _StartupError extends StatelessWidget {
  const _StartupError(this.error, this.stack);
  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Galla Pro could not start',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
                const SizedBox(height: 12),
                SelectableText('$error\n\n${stack ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // A widget build error normally paints a blank/grey page in release mode; show the message instead.
    ErrorWidget.builder = (details) => Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text('${details.exception}\n\n${details.stack}',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
            ),
          ),
        );

    try {
      // google-services.json makes Android create the default Firebase app itself, so only initialise when none exists.
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        } on FirebaseException catch (e) {
          if (e.code != 'duplicate-app') rethrow;
        }
      }
      await LocalDb.init();
      await AppPrefs.init();
      await Outbox.I.init();
    } catch (e, s) {
      debugPrint('STARTUP ERROR: $e\n$s');
      runApp(_StartupError(e, s));
      return;
    }

    runApp(const GallaProApp());
  }, (e, s) => debugPrint('UNCAUGHT: $e\n$s'));
}
