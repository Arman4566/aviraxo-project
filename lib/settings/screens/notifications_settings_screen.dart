import 'package:flutter/material.dart';
import '../../data/models/app_settings.dart';
import '../../data/repositories/app_settings_repo.dart';
import '../../receivables/receivables_screen.dart';
import '../../receivables/reminder_rules_screen.dart';
import '../../inventory/low_stock_screen.dart';
import '../../theme/gp_colors.dart';

/// Alerts the app really produces: payment reminders to send, low-stock list and the waiting-to-sync badge.
/// (Push notifications need a Firebase Cloud Messaging setup and are not part of this build.)
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  final _repo = AppSettingsRepo.I;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings>(
      stream: _repo.watchSettings(),
      builder: (context, snap) {
        final lowStock = snap.data?.draft?.lowStockAlerts ?? true;

        return Scaffold(
          appBar: AppBar(title: const Text("Alerts & Reminders", style: TextStyle(fontWeight: FontWeight.w900))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _link(
                icon: Icons.notifications_active_rounded,
                title: "Payment reminders",
                subtitle: "Choose when customers are reminded about unpaid bills",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderRulesScreen())),
              ),
              _link(
                icon: Icons.send_rounded,
                title: "Reminders to send today",
                subtitle: "One tap to send on WhatsApp, SMS or email",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivablesScreen(initialTab: 2))),
              ),
              const Divider(height: 32),
              SwitchListTile(
                value: lowStock,
                onChanged: (v) => _repo.setLowStockAlerts(v),
                title: const Text("Low stock alerts"),
                subtitle: const Text("Show low-stock warnings in the app"),
              ),
              _link(
                icon: Icons.warning_amber_rounded,
                title: "See low-stock items",
                subtitle: "With a suggested reorder quantity",
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LowStockScreen())),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _link({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: GPColors.tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: GPColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
