import 'package:flutter/material.dart';
import '../core/messenger.dart';
import '../models/onboarding_data.dart';
import '../base/base_screen.dart';
import '../data/repositories/onboarding_repo.dart';

// screens
import 'screens/ob_welcome_screen.dart';
import 'screens/ob_business_type_screen.dart';
import 'screens/ob_industry_screen.dart';
import 'screens/ob_gst_screen.dart';
import 'screens/ob_pricing_screen.dart';
import 'screens/ob_inventory_screen.dart';
import 'screens/ob_billing_screen.dart';
import 'screens/ob_business_details_screen.dart';
import 'screens/ob_complete_screen.dart';

class OnboardingFlow extends StatefulWidget {
  final OnboardingData initialData;
  final int initialIndex; // restore step

  const OnboardingFlow({
    super.key,
    required this.initialData,
    required this.initialIndex,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  // ✅ New last index because Team screen removed
  static const int _lastIndex = 8;

  late final OnboardingData _data;
  late final PageController _pageController;
  final _repo = OnboardingRepo();

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;

    // ✅ Clamp restore index safely (also handles old saved step=9)
    _index = widget.initialIndex.clamp(0, _lastIndex);
    _pageController = PageController(initialPage: _index);
  }

  Future<void> _persist() async {
    // save current step + all selected data
    await _repo.saveDraft(_data, _index);
  }

  Future<void> _go(int i) async {
    final target = i.clamp(0, _lastIndex);
    setState(() => _index = target);
    await _persist();

    if (!mounted) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> next() async {
    if (_index < _lastIndex) await _go(_index + 1);
  }

  Future<void> back() async {
    if (_index > 0) await _go(_index - 1);
  }

  Future<void> skip() async {
    // Skip for now -> still persist current state
    if (_index < _lastIndex) {
      await _go(_index + 1);
    } else {
      await _finishToDashboard();
    }
  }

  Future<void> _finishToDashboard() async {
    // ✅ Mark onboarding complete in DB
    try {
      await _repo.complete(_data); // creates the business on the server
    } catch (e) {
      AppMessenger.error(e);
      return; // stay on this screen so the user can retry
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => BaseScreen(data: _data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // 0
            OBWelcomeScreen(
              onStart: () => _go(1),
              onSkip: _finishToDashboard,
            ),

            // 1
            OBBusinessTypeScreen(
              data: _data,
              stepLabel: "Step 1 of 7 · Business type",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(),
            ),

            // 2
            OBIndustryScreen(
              data: _data,
              stepLabel: "Step 2 of 7 · Industry",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(),
            ),

            // 3
            OBGstScreen(
              data: _data,
              stepLabel: "Step 3 of 7 · GST",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(),
            ),

            // 4
            OBPricingScreen(
              data: _data,
              stepLabel: "Step 4 of 7 · Pricing",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(),
            ),

            // 5 ✅ simplified inventory screen
            OBInventoryScreen(
              data: _data,
              stepLabel: "Step 5 of 7 · Stock",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(),
            ),

            // 6
            OBBillingScreen(
              data: _data,
              stepLabel: "Step 6 of 7 · Billing",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(),
            ),

            // 7
            OBBusinessDetailsScreen(
              data: _data,
              stepLabel: "Step 7 of 7 · Details",
              onBack: () => back(),
              onSkip: () => skip(),
              onNext: () => next(), // goes to index 8 (complete)
            ),

            // 8 ✅ Complete screen
            OBCompleteScreen(
              onGoDashboard: _finishToDashboard,
              onAddFirstItem: _finishToDashboard,
              onCreateFirstInvoice: _finishToDashboard,
            ),
          ],
        ),
      ),
    );
  }
}
