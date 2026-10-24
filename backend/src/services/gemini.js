// Thin Google Gemini client (REST, no SDK). The API key stays on the server; the app never sees it.
const config = require('../config');
const { AppError } = require('../utils/errors');

const BASE = 'https://generativelanguage.googleapis.com/v1beta/models';

const isConfigured = () => !!config.geminiApiKey;

/**
 * generate({ system, contents, json, temperature, fetchImpl })
 * contents: [{ role: 'user'|'model', parts: [{ text } | { inlineData: { mimeType, data } }] }]
 * Returns the model's text. With json:true the model is told to answer with JSON only.
 */
async function generate({ system, contents, json = false, temperature = 0.3, maxTokens = 1024, fetchImpl = fetch }) {
  if (!isConfigured()) throw new AppError(503, 'AI is not set up on the server yet (missing GEMINI_API_KEY)');
  const body = {
    contents,
    generationConfig: { temperature, maxOutputTokens: maxTokens, ...(json ? { responseMimeType: 'application/json' } : {}) },
  };
  if (system) body.systemInstruction = { parts: [{ text: system }] };
  const models = [config.geminiModel, ...(config.geminiFallbackModels || [])].filter((m, i, all) => all.indexOf(m) === i);
  let res = null;
  let failure = new AppError(502, 'The AI service returned an error. Please try again.');
  for (let i = 0; i < models.length; i++) {
    const model = models[i];
    try {
      const r = await fetchImpl(`${BASE}/${encodeURIComponent(model)}:generateContent`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': config.geminiApiKey },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(40000),
      });
      if (r.ok) { res = r; break; }
      let detail = '';
      try { detail = (await r.text()).slice(0, 300); } catch { /* ignore */ }
      console.warn(`[ai] Gemini HTTP ${r.status} (model ${model})${i < models.length - 1 ? ', trying next model' : ''}: ${detail}`);
      failure = r.status === 429
        ? new AppError(429, 'AI usage limit reached for now. Please try again in a minute.')
        : new AppError(502, 'The AI service returned an error. Please try again.');
    } catch (e) {
      console.warn(`[ai] request to Gemini failed (model ${model}): ${e.name}: ${e.message}${e.cause ? ' / ' + (e.cause.code || e.cause.message) : ''}`);
      failure = new AppError(504, 'The AI service did not respond. Please try again.');
    }
    if (i < models.length - 1) await new Promise((r) => setTimeout(r, 300));
  }
  if (!res) throw failure;
  const data = await res.json();
  const text = (data.candidates?.[0]?.content?.parts || []).map((p) => p.text || '').join('').trim();
  if (!text) throw new AppError(502, 'The AI gave an empty answer. Please rephrase and try again.');
  return text;
}

/** Parse a JSON answer, tolerating a ```json fence. */
function parseJson(text) {
  const t = String(text).trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  try { return JSON.parse(t); } catch { throw new AppError(502, 'The AI answer could not be read. Please try again.'); }
}

module.exports = { generate, parseJson, isConfigured };
