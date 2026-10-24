import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../theme/gp_colors.dart';
import '../../auth/auth_service.dart';
import '../widgets/settings_tile.dart';
import 'business_settings_screen.dart';
import 'billing_settings_screen.dart';
import 'inventory_settings_screen.dart';
import 'tax_settings_screen.dart';
import 'users_roles_screen.dart';
import 'notifications_settings_screen.dart';
import 'app_preferences_screen.dart';
import 'help_support_screen.dart';
import '../../receivables/reminder_rules_screen.dart';
import '../../expenses/expenses_screen.dart';
import '../../inventory/low_stock_screen.dart';
import '../../insights/insights_screen.dart';
import '../../reports/finance_reports_screen.dart';
import 'backup_screen.dart';

class SettingsHomeScreen extends StatelessWidget {
  final OnboardingData data;
  const SettingsHomeScreen({super.key, required this.data});

  bool get _inventoryEnabled =>
      (data.businessType ?? "").toLowerCase() != "services";
  bool get _gstEnabled => data.gstRegistered == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: GPColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsTile(
            icon: Icons.store_rounded,
            title: "Business Details",
            subtitle: "Business info & branding",
            onTap: () => _open(context, BusinessSettingsScreen(data: data)),
          ),
          SettingsTile(
            icon: Icons.receipt_long_rounded,
            title: "Billing & Invoice",
            subtitle: "Invoice format & payments",
            onTap: () => _open(context, BillingSettingsScreen(data: data)),
          ),

          if (_inventoryEnabled)
            SettingsTile(
              icon: Icons.inventory_2_rounded,
              title: "Inventory",
              subtitle: "Stock & item defaults",
              onTap: () => _open(context, InventorySettingsScreen(data: data)),
            ),

          if (_gstEnabled)
            SettingsTile(
              icon: Icons.calculate_rounded,
              title: "Tax & GST",
              subtitle: "GST configuration",
              onTap: () => _open(context, TaxSettingsScreen(data: data)),
            ),

          SettingsTile(
            icon: Icons.group_rounded,
            title: "Users & Roles",
            subtitle: "Staff access & permissions",
            onTap: () => _open(context, const UsersRolesScreen()),
          ),
          SettingsTile(
            icon: Icons.notifications_active_rounded,
            title: "Payment Reminders",
            subtitle: "When to remind customers to pay",
            onTap: () => _open(context, const ReminderRulesScreen()),
          ),
          SettingsTile(
            icon: Icons.account_balance_wallet_outlined,
            title: "Expenses",
            subtitle: "Track spending & other income",
            onTap: () => _open(context, const ExpensesScreen()),
          ),
          if (_inventoryEnabled)
            SettingsTile(
              icon: Icons.warning_amber_rounded,
              title: "Low Stock",
              subtitle: "Items to reorder",
              onTap: () => _open(context, const LowStockScreen()),
            ),
          SettingsTile(
            icon: Icons.auto_graph_rounded,
            title: "Insights & Forecast",
            subtitle: "Tips and cash outlook",
            onTap: () => _open(context, const InsightsScreen()),
          ),
          SettingsTile(
            icon: Icons.assessment_outlined,
            title: "Profit, Cash & GST Reports",
            subtitle: "P&L, day book, GSTR-1, GSTR-3B",
            onTap: () => _open(context, const FinanceReportsScreen()),
          ),
          SettingsTile(
            icon: Icons.backup_outlined,
            title: "Backup",
            subtitle: "Export a copy of your data",
            onTap: () => _open(context, const BackupScreen()),
          ),
          SettingsTile(
            icon: Icons.notifications_rounded,
            title: "Notifications",
            subtitle: "Alerts & reminders",
            onTap: () => _open(context, const NotificationsSettingsScreen()),
          ),
          SettingsTile(
            icon: Icons.palette_rounded,
            title: "App Preferences",
            subtitle: "Light & dark appearance",
            onTap: () => _open(context, const AppPreferencesScreen()),
          ),
          SettingsTile(
            icon: Icons.help_outline_rounded,
            title: "Help & Support",
            subtitle: "Help center & policies",
            onTap: () => _open(context, const HelpSupportScreen()),
          ),
          SettingsTile(
            icon: Icons.logout_rounded,
            title: "Sign out",
            subtitle: "Your data stays safe on the server",
            onTap: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await AuthService.I.signOut();
            },
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
