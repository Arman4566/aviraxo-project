import '../local_db.dart';
import '../models/app_settings.dart';
import '../../core/messenger.dart';
import 'business_sync.dart';

class AppSettingsRepo {
  AppSettingsRepo._();
  static final AppSettingsRepo I = AppSettingsRepo._();

  Future<AppSettings> getSettings() async {
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

  Stream<AppSettings> watchSettings() async* {
    await getSettings();
    yield* LocalDb.I.watchSettings().map((v) => v ?? (AppSettings()..id = 0));
  }

  Future<void> update(void Function(AppSettings s) mutate) async {
    final s = await getSettings();
    mutate(s);
    await LocalDb.I.putSettings(s);

    // Keep the server copy in step (needed e.g. for "allow negative stock", which the server enforces).
    if (s.onboarded) {
      try {
        await BusinessSync.push(s);
      } catch (e) {
        AppMessenger.error(e);
      }
    }
  }

  Future<void> setLowStockAlerts(bool v) async {
    await update((s) {
      s.draft ??= OnboardingDraft();
      s.draft!.lowStockAlerts = v;
    });
  }

  Future<void> setTrackInventory(bool v) async {
    await update((s) {
      s.draft ??= OnboardingDraft();
      s.draft!.trackInventory = v;
    });
  }

  Future<void> setBarcodeUsage(bool v) async {
    await update((s) {
      s.draft ??= OnboardingDraft();
      s.draft!.barcodeUsage = v;
    });
  }

  Future<void> setGstType(String gstType) async {
    await update((s) {
      s.draft ??= OnboardingDraft();
      s.draft!.gstType = gstType;
    });
  }
}
