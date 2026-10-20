import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../local_db.dart';
import '../models/app_settings.dart';
import 'business_sync.dart';
import 'inventory_repo.dart';
import 'invoice_repo.dart';
import 'party_repo.dart';

/// Runs right after sign-in: asks the server who this user is and whether they already have a business.
///  - business exists  -> local settings are filled from it and onboarding is skipped (works on a new phone too)
///  - no business yet  -> onboarding starts (local leftovers from another account are cleared)
class SessionBootstrap {
  static const _uidKey = 'gp_last_uid';

  static Future<void> run(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final sameUser = prefs.getString(_uidKey) == user.uid;

    InventoryRepo.reset();
    PartyRepo.reset();
    InvoiceRepo.reset();

    final me = await ApiClient.I.get('/me');
    final business = me['business'] as Map<String, dynamic>?;
    var s = await LocalDb.I.getSettings() ?? (AppSettings()..id = 0);
    if (business != null) {
      BusinessSync.applyTo(s, business);
    } else if (!sameUser) {
      // a different account used this phone before: start clean
      s = AppSettings()
        ..id = 0
        ..onboarded = false
        ..onboardingStep = 0
        ..draft = OnboardingDraft();
    } else if (s.onboarded) {
      // this account has no business on the server, so onboarding must be done again
      s.onboarded = false;
      s.onboardingStep = 0;
    }
    await LocalDb.I.putSettings(s);

    await prefs.setString(_uidKey, user.uid);
  }
}
