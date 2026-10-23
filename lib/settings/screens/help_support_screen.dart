import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import 'package:flutter/services.dart';
import '../../auth/auth_service.dart';
import '../../core/messenger.dart';
import '../../legal/privacy_policy_screen.dart';
import '../../legal/terms_conditions_screen.dart';
import '../../theme/gp_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // Change this to your real support address before release.
  static const String supportEmail = "example@gmail.com";

  static const _faq = <(String, String)>[
    ("How do I send a payment reminder?", "Open Collect Payments from the menu, tap a customer, pick WhatsApp, SMS or email. The message is already written. Add your UPI ID in Billing & Invoice to include a pay link."),
    ("How do reminders work automatically?", "Rules decide who needs a reminder each day. Open the bell icon to see today's list and send each with one tap. Customers who promised a date are skipped until then."),
    ("Can I bill without internet?", "Yes. Invoices, payments and expenses are saved on your phone and sent when you are back online. The cloud icon at the top shows how many are waiting."),
    ("How do I add staff?", "Settings, then Users & Roles, then Invite. They join when they sign in with that email."),
    ("How do I back up my data?", "Settings, then Backup, then Export. Save the file in Drive or email it to yourself."),
    ("How do I change language or theme?", "Settings, then App Preferences. Hindi and dark mode are available."),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Common questions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          for (final q in _faq)
            Card(
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(q.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(q.$2)],
              ),
            ),
          const SizedBox(height: 12),
          _tile(context, Icons.support_agent_rounded, "Contact support", supportEmail, () async {
            await Clipboard.setData(const ClipboardData(text: supportEmail));
            AppMessenger.info("Support email copied: $supportEmail");
          }),
          _tile(context, Icons.privacy_tip_rounded, "Privacy Policy", null, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
          _tile(context, Icons.description_rounded, "Terms of Use", null, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsConditionsScreen()))),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: GPColors.danger),
            icon: const Icon(Icons.logout_rounded),
            label: const Text("Sign out"),
            onPressed: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await AuthService.I.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String? sub, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: GPColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: sub == null ? null : Text(sub),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
