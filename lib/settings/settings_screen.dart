import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';
import 'screens/settings_home_screen.dart';

class SettingsScreen extends StatelessWidget {
  final OnboardingData data;
  const SettingsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SettingsHomeScreen(data: data);
  }
}
