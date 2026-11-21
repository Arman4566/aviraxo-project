# Security notes

## What the server enforces
- Every `/api` route needs a valid Firebase ID token (signature, audience, issuer, expiry checked). Dev tokens (`dev:`) are refused when `NODE_ENV=production`.
- Every business query is filtered by the signed-in user's business; roles are checked per route (deny by default).
- Staff invitations are only honoured for an email the sign-in provider has verified.
- Rate limits: per address, per address without a token, per user for AI/export/backup, per business for AI per hour.
- Large uploads (12 MB) are only read after the caller is authenticated.
- CORS: no browser origin is allowed unless listed in `CORS_ORIGINS`. The mobile app is not affected.
- Responses are `Cache-Control: no-store`; every response has an `X-Request-Id` to trace problems in the logs.
- Database error details are not sent to clients in production; the database connection verifies the TLS certificate.
- Uploaded .xlsx files are size-limited when unpacked (zip-bomb guard); CSV exports neutralise spreadsheet formulas.

## Your checklist (things code cannot do for you)
1. Render: `NODE_ENV=production`, no `DEV_AUTH`.
2. Rotate `GEMINI_API_KEY` and the Neon password if they were ever pasted anywhere public.
3. Firebase console: Authentication > Settings > turn on **email enumeration protection**; add your release SHA-1/SHA-256; restrict the Android API key to your app's package + SHA.
4. Neon: use a role with only the access the app needs; turn on backups/point-in-time restore.
5. Android release: `--obfuscate --split-debug-info=build/symbols`, `android:allowBackup="false"`, `android:usesCleartextTraffic="false"`.
6. Keep `.env`, `google-services.json` secrets and signing keystores out of Git.
