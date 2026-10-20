import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/local_db.dart';
import 'api_client.dart';

/// Offline billing: writes that fail because there is no internet are kept on this phone and sent later.
/// Every queued write carries a `client_ref`, which the server uses to ignore a duplicate if a retry arrives twice,
/// so a flaky connection can never create two invoices or two payments.
class Outbox {
  Outbox._();
  static final Outbox I = Outbox._();

  /// How many writes are waiting. Show it in the UI ("3 waiting to sync").
  final ValueNotifier<int> pending = ValueNotifier<int>(0);
  bool _flushing = false;

  /// Paths that are safe to queue (the server makes them idempotent through client_ref).
  static const Set<String> queueable = {'/invoices', '/payments', '/expenses'};

  static String newRef() {
    final r = Random.secure();
    final bytes = List<int>.generate(10, (_) => r.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'app-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$hex';
  }

  Database get _db => LocalDb.I.rawDb;

  Future<void> init() async {
    await refreshCount();
  }

  Future<void> refreshCount() async {
    final n = Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM outbox WHERE failed = 0')) ?? 0;
    pending.value = n;
  }

  Future<void> enqueue(String path, Map<String, dynamic> body) async {
    await _db.insert('outbox', {
      'path': path,
      'body': jsonEncode(body),
      'created_at': DateTime.now().toIso8601String(),
      'failed': 0,
      'error': '',
    });
    await refreshCount();
  }

  /// Items the server refused (for example a stock shortage). Shown so the owner can fix them instead of losing them.
  Future<List<Map<String, Object?>>> failed() => _db.query('outbox', where: 'failed = 1', orderBy: 'id');

  Future<void> discard(int id) async {
    await _db.delete('outbox', where: 'id = ?', whereArgs: [id]);
    await refreshCount();
  }

  /// Sends everything waiting, oldest first. Stops quietly at the first network failure.
  Future<int> flush() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final rows = await _db.query('outbox', where: 'failed = 0', orderBy: 'id');
      for (final row in rows) {
        final id = row['id'] as int;
        try {
          await ApiClient.I.post(row['path'] as String, jsonDecode(row['body'] as String) as Object);
          await _db.delete('outbox', where: 'id = ?', whereArgs: [id]);
          sent++;
        } on ApiException catch (e) {
          if (e.isNetwork) break; // still offline: try again later, keep the order
          // The server understood and said no (validation, stock, permission): keep it visible instead of retrying forever.
          await _db.update('outbox', {'failed': 1, 'error': e.message}, where: 'id = ?', whereArgs: [id]);
        }
      }
    } finally {
      _flushing = false;
      await refreshCount();
    }
    return sent;
  }
}
