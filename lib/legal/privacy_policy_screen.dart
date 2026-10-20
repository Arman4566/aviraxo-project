import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _text = """Privacy Policy – Galla Pro

Last updated: 4th February 2026.

Galla Pro is a simple inventory, billing, and invoice management application designed to help businesses manage basic data and calculations. This Privacy Policy explains how we handle user data at the MVP (Minimum Viable Product) stage.

1. Data Collection & Usage

Galla Pro may collect and store the following data entered by the user:

Business details

Customer information

Inventory and item details

Invoice and billing data

This data is used only to provide app functionality such as calculations, invoice generation, and data display.

2. Data Backup & Sync

User data may be synced to our servers to enable backup and restore functionality.

This backup allows users to recover their data when changing or reinstalling devices.

Server storage is provided as a convenience feature, not as guaranteed permanent storage.

3. Offline Usage

Galla Pro can be used offline.

When used offline:

Data is stored only on the user’s device

No server backup is created

If the device data is lost while offline, the app is not responsible for recovery.

4. Data Safety Disclaimer

We take reasonable measures to protect user data.

However, the app does not guarantee protection against data loss due to:

Device damage

App reinstallation

OS issues

User actions

Network or server issues

5. Invoice & PDF Responsibility

The app allows users to create invoices and generate PDFs.

Users are strongly advised to download and save invoice PDFs to their own devices or external storage.

Galla Pro is not responsible for loss of invoices if they are not saved by the user.

6. Third-Party Services

At the MVP stage, limited third-party services (such as hosting or analytics) may be used strictly to support app functionality.

7. Policy Updates

This Privacy Policy may be updated as the app evolves. Continued use of the app implies acceptance of any changes.
""";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Privacy Policy",
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
