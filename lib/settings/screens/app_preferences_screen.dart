import 'package:flutter/material.dart';

import '../../core/outbox.dart';
import '../../core/prefs.dart';
import '../../core/messenger.dart';
import '../../l10n/strings.dart';
import '../../theme/gp_colors.dart';
import 'backup_screen.dart';

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPrefs.I;
    return Scaffold(
      appBar: AppBar(title: Text('${tr('language')} & ${tr('theme')}', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: ValueListenableBuilder<String>(
        valueListenable: p.language,
        builder: (_, lang, __) => ValueListenableBuilder<ThemeMode>(
          valueListenable: p.themeMode,
          builder: (_, mode, __) => ListView(padding: const EdgeInsets.all(16), children: [
            Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w900)),
            RadioListTile<String>(value: 'en', groupValue: lang, onChanged: (v) => p.setLanguage(v!), title: const Text('English')),
            RadioListTile<String>(value: 'hi', groupValue: lang, onChanged: (v) => p.setLanguage(v!), title: const Text('हिन्दी (Hindi)')),
            const Divider(),
            Text(tr('theme'), style: const TextStyle(fontWeight: FontWeight.w900)),
            RadioListTile<ThemeMode>(value: ThemeMode.light, groupValue: mode, onChanged: (v) => p.setThemeMode(v!), title: Text(tr('light'))),
            RadioListTile<ThemeMode>(value: ThemeMode.dark, groupValue: mode, onChanged: (v) => p.setThemeMode(v!), title: Text(tr('dark'))),
            RadioListTile<ThemeMode>(value: ThemeMode.system, groupValue: mode, onChanged: (v) => p.setThemeMode(v!), title: Text(tr('system'))),
            const Divider(),
            ValueListenableBuilder<int>(
              valueListenable: Outbox.I.pending,
              builder: (_, n, __) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: Text(n == 0 ? 'Everything is synced' : tr('pending_sync', {'n': '$n'})),
                trailing: n == 0
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final sent = await Outbox.I.flush();
                          AppMessenger.info(sent > 0 ? '$sent sent' : 'Still offline. Will retry automatically.');
                        },
                        child: Text(tr('sync_now')),
                      ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_outlined),
              title: Text(tr('backup')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
            const Divider(),
            const Text('App version 1.1.0', style: TextStyle(color: GPColors.ink2)),
          ]),
        ),
      ),
    );
  }
}
