import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'core/outbox.dart';
import 'core/prefs.dart';
import 'data/local_db.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // On-device SQLite (preferences only)
  await LocalDb.init();
  await AppPrefs.init();
  await Outbox.I.init();

  runApp(const GallaProApp());
}
