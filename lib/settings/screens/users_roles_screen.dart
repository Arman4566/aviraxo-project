import 'package:flutter/material.dart';

import '../../core/messenger.dart';
import '../../data/repositories/extras_repo.dart';
import '../../l10n/strings.dart';

/// Real team management: invite staff by email, change roles, remove people. Only the owner (or anyone with
/// the staff permission) can change things; the server enforces it, this screen just shows the server's answer.
class UsersRolesScreen extends StatefulWidget {
  const UsersRolesScreen({super.key});
  @override
  State<UsersRolesScreen> createState() => _UsersRolesScreenState();
}

class _UsersRolesScreenState extends State<UsersRolesScreen> {
  final _repo = ExtrasRepo();
  late Future<Map<String, dynamic>> _future = _repo.staff();
  void _reload() => setState(() => _future = _repo.staff());

  static const _roleHelp = {
    'manager': 'Everything except team and restore',
    'cashier': 'Create invoices and take payments; cannot see cost or profit',
    'accountant': 'Reports, GST and expenses; cannot bill',
    'viewer': 'View only',
  };

  Future<void> _invite() async {
    final email = TextEditingController();
    String role = 'cashier';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(tr('invite')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Their email (the one they sign in with)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [for (final e in _roleHelp.entries) DropdownMenuItem(value: e.key, child: Text(e.key))],
              onChanged: (v) => set(() => role = v ?? role),
            ),
            const SizedBox(height: 8),
            Text(_roleHelp[role]!, style: Theme.of(c).textTheme.bodySmall),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('invite')))],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _repo.invite(email.text.trim(), role);
      AppMessenger.info('Invited. They join automatically when they sign in with that email.');
      _reload();
    } catch (e) {
      AppMessenger.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('team'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _invite, icon: const Icon(Icons.person_add_alt), label: Text(tr('invite'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: TextButton(onPressed: _reload, child: Text('${snap.error}. ${tr('retry')}')));
          final members = List<Map<String, dynamic>>.from(snap.data!['members'] as List);
          final invites = List<Map<String, dynamic>>.from(snap.data!['invites'] as List);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
            for (final m in members)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(('${m['name'] ?? m['email']}').characters.first.toUpperCase())),
                  title: Text('${m['name'] ?? m['email']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${m['email']}'),
                  trailing: m['role'] == 'owner'
                      ? const Chip(label: Text('owner'))
                      : PopupMenuButton<String>(
                          child: Chip(label: Text('${m['role']}')),
                          onSelected: (v) async {
                            try {
                              if (v == 'remove') {
                                await _repo.removeMember((m['id'] as num).toInt());
                              } else {
                                await _repo.changeRole((m['id'] as num).toInt(), v);
                              }
                              _reload();
                            } catch (e) {
                              AppMessenger.error(e);
                            }
                          },
                          itemBuilder: (_) => [
                            for (final r in _roleHelp.keys) PopupMenuItem(value: r, child: Text('Make $r')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove from team')),
                          ],
                        ),
                ),
              ),
            if (invites.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Waiting to join', style: Theme.of(context).textTheme.titleMedium),
              for (final i in invites)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text('${i['email']}'),
                    subtitle: Text('${i['role']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cancel invite',
                      onPressed: () async {
                        try {
                          await _repo.revokeInvite((i['id'] as num).toInt());
                          _reload();
                        } catch (e) {
                          AppMessenger.error(e);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ]);
        },
      ),
    );
  }
}
