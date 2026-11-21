require('dotenv').config();

const isProd = process.env.NODE_ENV === 'production';

module.exports = {
  port: Number(process.env.PORT || 4000),
  databaseUrl: process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/galla_pro',
  firebaseProjectId: process.env.FIREBASE_PROJECT_ID || 'galla-pro-b61ef',
  // Dev tokens are never accepted in production, whatever the env says.
  devAuth: !isProd && String(process.env.DEV_AUTH).toLowerCase() === 'true',
  // AI features (Google Gemini). Leave the key empty to switch AI off; the rest of the app keeps working.
  geminiApiKey: process.env.GEMINI_API_KEY || '',
  geminiModel: process.env.GEMINI_MODEL || 'gemini-3.8-flash',
  // Tried in order when the main model is overloaded (503), rate limited or unavailable.
  geminiFallbackModels: (process.env.GEMINI_FALLBACK_MODELS || 'gemini-3.8-flash,gemini-3.6-flash,gemini-3.5-flash-lite')
    .split(',').map((m) => m.trim()).filter(Boolean),
  // Browser origins allowed to call the API (comma separated). The mobile app needs none.
  corsOrigins: (process.env.CORS_ORIGINS || '').split(',').map((o) => o.trim()).filter(Boolean),
  // Requests per minute per client address, and per signed-in user for heavy endpoints (AI, export, backup).
  rateLimitPerMin: Number(process.env.RATE_LIMIT_PER_MIN || 240),
  heavyLimitPerMin: Number(process.env.HEAVY_LIMIT_PER_MIN || 20),
  authFailLimit: Number(process.env.AUTH_FAIL_LIMIT || 30),
  aiHourlyLimit: Number(process.env.AI_HOURLY_LIMIT || 40),
  isProd,
};
