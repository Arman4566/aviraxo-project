# Deploy: Neon (database) + Render (server)

## 1. Neon – the PostgreSQL database
1. Sign up at neon.tech → Create project (name `galla-pro`, region closest to India, e.g. Singapore).
2. Dashboard → **Connection string** → copy it. It looks like
   `postgresql://user:password@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`
3. (Optional, to create tables from your PC first) put it in `.env` as `DATABASE_URL=...` and run `npm run migrate`.
   Render also runs the migration on every start, so this is not required.

## 2. Render – the Node server
1. Push the `backend` folder to a GitHub repo (the `.env` file must NOT be pushed; `node_modules` neither).
2. render.com → New → **Web Service** → pick the repo (or New → Blueprint, which reads `render.yaml`).
3. Settings if you fill them by hand: Runtime Node · Build `npm install` · Start `npm run migrate && npm start` · Health check `/health`.
4. Environment variables: `DATABASE_URL` = your Neon string, `FIREBASE_PROJECT_ID` = `galla-pro-b61ef`, `NODE_ENV` = `production`.
5. Deploy. Your API address is `https://<service-name>.onrender.com`. Test: open `/health` → `{"status":"ok"}`.

Free Render services sleep after ~15 min idle; the first request after that takes ~30-60 s. The app shows
"server took too long" once in that case; just retry. (Paid plan or a ping service removes this.)

## 3. Point the Flutter app at it
`flutter run --dart-define=API_BASE_URL=https://<service-name>.onrender.com`
(release builds: add the same flag to `flutter build apk`).
