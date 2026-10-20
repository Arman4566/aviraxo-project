import '../../models/onboarding_data.dart';
import '../local_db.dart';
import '../models/app_settings.dart';

class WorkspaceRepo {
  /// Watches the settings row. Rebuilds UI whenever settings change.
  Stream<AppSettings?> watchSettings() => LocalDb.I.watchSettings();

  /// Loads current onboarding/workspace data snapshot (from local SQLite).
  Future<OnboardingData> loadWorkspaceData() async {
    final s = await LocalDb.I.getSettings();
    return OnboardingData.fromDraft(s?.draft);
  }
}
