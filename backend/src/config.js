require('dotenv').config();

const isProd = process.env.NODE_ENV === 'production';

module.exports = {
  port: Number(process.env.PORT || 4000),
  databaseUrl: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/galla_pro',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || 'galla-pro-b61ef',
  // Dev tokens are never accepted in production, whatever the env says.
  devAuth: !isProd && String(process.env.DEV_AUTH).toLowerCase() === 'true',
  isProd,
};
