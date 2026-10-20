import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models/app_settings.dart';

/// On-device SQLite database. It only keeps this phone's preferences and the onboarding draft.
/// Business data (items, parties, invoices...) lives on the server.
const String _outboxSql =
    'CREATE TABLE IF NOT EXISTS outbox (id INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL, body TEXT NOT NULL, '
    'created_at TEXT NOT NULL, failed INTEGER NOT NULL DEFAULT 0, error TEXT NOT NULL DEFAULT \'\')';

class LocalDb {
  LocalDb._();
  static final LocalDb I = LocalDb._();

  late final Database _db;
  Database get rawDb => _db;
  final StreamController<AppSettings?> _changes = StreamController<AppSettings?>.broadcast();

  static Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'galla_pro.db');
    I._db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE app_settings (id INTEGER PRIMARY KEY, json TEXT NOT NULL)');
        await db.execute(_outboxSql);
      },
      onUpgrade: (db, from, to) async {
        if (from < 2) await db.execute(_outboxSql);   // v2: offline queue
      },
    );
  }

  Future<AppSettings?> getSettings() async {
    final rows = await _db.query('app_settings', where: 'id = 0', limit: 1);
    if (rows.isEmpty) return null;
    return AppSettings.fromJson(jsonDecode(rows.first['json'] as String) as Map<String, dynamic>);
  }

  Future<void> putSettings(AppSettings s) async {
    s.id = 0;
    await _db.insert(
      'app_settings',
      {'id': 0, 'json': jsonEncode(s.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _changes.add(s);
  }

  /// Emits the current settings, then again after every save.
  Stream<AppSettings?> watchSettings() async* {
    yield await getSettings();
    yield* _changes.stream;
  }
}
