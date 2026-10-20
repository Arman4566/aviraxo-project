import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';
import 'screens/reports_home_screen.dart';

class ReportsScreen extends StatelessWidget {
  final OnboardingData data;
  const ReportsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ReportsHomeScreen(data: data);
  }
}
