import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/messenger.dart';
import '../../data/repositories/extras_repo.dart';
import '../../l10n/strings.dart';

/// Download every record as one JSON file and share it (Drive, email, WhatsApp to yourself).
/// Restore is done on the server into an empty firm; see the backend README.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await ExtrasRepo().backupExport();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final name = 'galla-pro-backup-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final f = File('${dir.path}/$name');
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles([XFile(f.path)], subject: 'Galla Pro backup');
    } catch (e) {
      AppMessenger.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('backup'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your data is already stored safely on the server. A backup file is your own extra copy: all parties, items, invoices, payments and expenses in one file.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.download), label: Text(_busy ? 'Preparing…' : 'Export backup')),
          const SizedBox(height: 16),
          const Text('To restore, create a new empty firm and ask the owner to upload the file; only the owner can restore.'),
        ]),
      ),
    );
  }
}
