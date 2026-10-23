# Flutter changes: phases 2-6

**These changes were written without a Flutter SDK, so nothing has been compiled.** Before anything else run:

    flutter pub get
    flutter analyze
    flutter run --dart-define=API_BASE_URL=https://your-backend

Expect a few small analyzer fixes (imports, nullability). Run `npm run migrate` on the backend first.

## New files
- `core/prefs.dart` language, theme and selected firm (stored on the device)
- `core/outbox.dart` offline queue; `ApiClient.postQueued` stores invoice, payment and expense writes when there is no internet and sends them later with a `client_ref` so retries cannot duplicate
- `l10n/strings.dart` English and Hindi strings: `tr('key')`. Add new keys to both maps
- `receivables/` receivables screen (Outstanding / Aging / Reminders today), reminder sheet (WhatsApp, SMS, email, UPI link, promise to pay, skip), reminder rules editor
- `expenses/expenses_screen.dart`, `inventory/low_stock_screen.dart`, `insights/insights_screen.dart`, `reports/finance_reports_screen.dart`, `settings/screens/backup_screen.dart`
- `data/repositories/receivables_repo.dart`, `extras_repo.dart`

## Changed
- `app.dart`, `main.dart`: dark theme, language switch, prefs and outbox start-up
- `theme/`: dark theme and semantic colours
- `data/local_db.dart`: database version 2 (adds the `outbox` table, migrates existing installs)
- `settings/screens/users_roles_screen.dart`: replaced the fake users with real invite / role / remove
- `settings/screens/app_preferences_screen.dart`: real language and theme, sync status
- `settings_home_screen.dart`: tiles for reminders, expenses, low stock, insights, reports, backup
- `dashboard/dashboard_screen.dart`: quick actions open real screens (Collect Payments, Expenses, Insights, Overdue List...), unsent offline entries are flushed on open and refresh
- Payment and invoice saving are offline-safe and double-tap-safe
- Onboarding: named steps with a progress bar, GSTIN format check with an inline message, "GST Invoice" hidden when not GST registered, removed the "Phase-0" text
- `widgets/gp_inputs.dart`: error text, helper text, required marker

## Known gaps
- Dark mode: new screens follow the theme; older screens that use `GPColors.white/bg` directly stay light until migrated
- Barcode scanning: `mobile_scanner` is in `pubspec.yaml` and the backend lookup exists (`ExtrasRepo.itemByBarcode`), but the scanner button is not yet placed in the invoice item picker
- Invoice template choices, regional languages other than Hindi, purchase bills, e-Way bill, voice billing and bill scanning are not built
- Android needs the `INTERNET` permission (already there) and `<queries>` entries for `https`, `sms`, `mailto` so `url_launcher` can open WhatsApp, SMS and email

## Latest round: look, analytics, working features
- New indigo palette + light/dark themes (lib/theme). Dashboard hero header and sales-trend chart.
- Analytics dashboard (drawer > Analytics): revenue, profit, trends, top items/customers, payment modes, weekdays. Charts are hand-drawn (lib/widgets/charts.dart); all four report screens now show real charts.
- Navigation: every new screen is reachable from the drawer / app-bar.
- Settings that now work: billing (invoice template, UPI id), tax, inventory toggles, notifications, help, business edit. Invoice PDF has 3 templates.
- Barcode scanning (mobile_scanner): item form, item list search, invoice add-item sheet.
  Android: CAMERA permission; iOS: NSCameraUsageDescription in Info.plist.
- Run `flutter pub get` then `flutter analyze`.

## AI features (Gemini via the backend)
- lib/ai/ask_screen.dart: chat over your own business numbers (English/Hindi). Drawer > Ask AI.
- lib/ai/ai_summary_card.dart: dashboard "AI business check-up" (generated on tap, so it uses no quota until asked).
- Reminder sheet: "Write with AI" chip; the amount is guaranteed unchanged, plain text is the fallback.
- lib/ai/scan_bill_screen.dart: photo of a supplier bill -> checked item list -> added to inventory with stock. Drawer > Scan Bill (AI).
- New dependency: image_picker. iOS Info.plist needs NSCameraUsageDescription and NSPhotoLibraryUsageDescription.
- Server needs GEMINI_API_KEY (Render > Environment).

## Hindi, dark mode and glass look
- **Glass look (light + dark):** gradient backdrop on every page (lib/widgets/glass.dart), see-through cards, frosted app bar / bottom bar / sheets (`showGlassSheet`), iPhone-style page slide. Colours live in lib/theme/gp_colors.dart; both modes come from one builder in lib/theme/app_theme.dart.
- **Dark mode:** Settings > App Preferences or the switch at the top of the drawer (sun/moon button). "System" follows the phone. All `GPColors` are now mode-aware getters, so widgets that use them are no longer `const`.
- **Hindi:** language switch in the same two places. Every `Text` is now `lib/l10n/gtext.dart`, which looks the string up in `lib/l10n/hi_phrases.dart` (about 930 phrases, 110 sentence patterns, Privacy Policy and Terms). Text with no Hindi entry shows in English. Hindi date pickers/dialogs come from flutter_localizations.
- To add or fix a Hindi word, edit `hi_phrases.dart` (`'English text': 'हिन्दी'`). Sentences with numbers/names use `{0}`, `{1}` in `hiPatterns`.
- Not translated: invoice PDFs, text coming from your own data (item/customer names), and AI answers (the AI answers in the language you ask in).
- Switching language/theme rebuilds every widget in place (see `_changed` in lib/app.dart), so you stay on the same screen.
