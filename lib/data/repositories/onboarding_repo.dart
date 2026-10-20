import '../../models/onboarding_data.dart';
import '../local_db.dart'; 
import '../models/app_settings.dart';
import 'business_sync.dart';

class OnboardingRepo {
  static const int _completeStepIndex = 8;

  Future<AppSettings> _getOrCreate() async {
    final existing = await LocalDb.I.getSettings();
    if (existing != null) return existing;

    final fresh = AppSettings()
      ..id = 0
      ..onboarded = false
      ..onboardingStep = 0
      ..draft = OnboardingDraft();

    await LocalDb.I.putSettings(fresh);

    return fresh;
  }

  Future<({bool onboarded, int step, OnboardingData data})> load() async {
    final s = await _getOrCreate();
    final data = OnboardingData.fromDraft(s.draft);
    return (onboarded: s.onboarded, step: s.onboardingStep, data: data);
  }

  Future<void> saveDraft(OnboardingData data, int step) async {
    final s = await _getOrCreate();
    s.onboardingStep = step;
    s.draft = data.toDraft();

    await LocalDb.I.putSettings(s);

  }

  Future<void> complete(OnboardingData data) async {
    final s = await _getOrCreate();
    s.onboarded = true;
    s.onboardingStep = _completeStepIndex;
    s.draft = data.toDraft();

    // The business is created on the server first. If this fails the user stays in onboarding and sees the error.
    await BusinessSync.push(s);

    await LocalDb.I.putSettings(s);

  }

  Future<void> resetOnboarding() async {
    final s = await _getOrCreate();
    s.onboarded = false;
    s.onboardingStep = 0;
    s.draft = OnboardingDraft();

    await LocalDb.I.putSettings(s);

  }
}
