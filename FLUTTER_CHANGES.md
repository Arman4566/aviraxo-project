# Galla Pro – Phase 1 Flutter changes (backend = source of truth)

1. Copy this `lib/` over your project's `lib/` and this `pubspec.yaml` additions (`http: ^1.2.2`). Run `flutter pub get`.
2. DELETE if still present: `lib/data/models/*.g.dart`, `lib/data/isar_service.dart`, `lib/auth/backup/`.
   Isar is gone. The on-device database is now **SQLite** (`sqflite`, see `lib/data/local_db.dart`); it only keeps this phone's
   preferences and onboarding draft. Business data is in Neon (PostgreSQL) via the Render server.
3. Run with the server address: `flutter run --dart-define=API_BASE_URL=https://<your-service>.onrender.com`
   (local backend instead: `http://10.0.2.2:4000` on the emulator). See backend `DEPLOY.md`.
4. Old local items/parties/invoices are NOT migrated. Guest mode is removed (login required).

New: `core/` (api client, money, messenger), `payments/record_payment_sheet.dart`, `invoices/invoice_detail_screen.dart`,
`inventory/widgets/adjust_stock_dialog.dart`, `data/repositories/{cached_list,business_sync,session_bootstrap,payment_repo}.dart`.
This was written without a Flutter SDK, so run `flutter analyze` and send me any errors.
