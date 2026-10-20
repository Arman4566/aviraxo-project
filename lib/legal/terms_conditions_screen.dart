import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const String _text = """Terms & Conditions – Galla Pro

Last updated: 4th February 2026.

By using Galla Pro, you agree to the following Terms & Conditions.

1. Nature of the Application

Galla Pro is a calculation and data-management tool.

The app performs calculations only based on user input.

If incorrect data is entered, the app cannot be held responsible for incorrect results.

2. Accuracy & Responsibility

Users are fully responsible for:

Entered data

Generated invoices

Tax values, totals, and calculations

Galla Pro does not provide legal, tax, or financial advice.

3. Data Loss Disclaimer

The app is not responsible for:

Loss of data

Corrupted files

Missing invoices

Backup failures

Especially during offline usage, no server backup is guaranteed.

4. Invoice Usage

Generated invoices should be reviewed by the user before sharing.

Users are advised to download and store invoice PDFs manually.

The app is not liable for disputes arising from incorrect invoices.

5. MVP Limitation

Galla Pro is currently provided as an MVP (Minimum Viable Product).

Features, data handling, and performance may change in future updates.

Temporary issues or feature limitations may exist.

6. Limitation of Liability

To the maximum extent permitted by law:

Galla Pro and its developers are not liable for any direct or indirect damages.

The app is used at the user’s own risk.

7. Acceptance

By installing or using Galla Pro, you confirm that you:

Understand these terms

Accept the limitations of the app

Agree to use it responsibly
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Terms & Conditions",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _text,
            style: const TextStyle(height: 1.35, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
