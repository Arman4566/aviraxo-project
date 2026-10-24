import '../../core/api_client.dart';

/// AI features. The Gemini key lives on the server; the app only talks to our own API.
class AiRepo {
  /// Gemini can take a while (plus a sleeping free-tier server), so AI calls wait longer than normal requests.
  static const Duration _aiTimeout = Duration(seconds: 75);

  Future<bool> enabled() async {
    try {
      final r = await ApiClient.I.get('/ai/status');
      return r['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// history: [{role: 'user'|'assistant', text: ...}] (the last few turns are sent for follow-up questions).
  Future<String> ask(String question, List<Map<String, String>> history) async {
    final r = await ApiClient.I.post('/ai/ask', {'question': question, 'history': history}, _aiTimeout);
    return (r['answer'] as String?) ?? '';
  }

  Future<Map<String, dynamic>> summary() => ApiClient.I.get('/ai/summary', timeout: _aiTimeout);

  Future<Map<String, dynamic>> reminderDraft(int partyId, {String? tone, String language = 'en', String? hint}) =>
      ApiClient.I.post('/ai/reminder-draft', {
        'party_id': partyId,
        if (tone != null) 'tone': tone,
        'language': language,
        if (hint != null && hint.trim().isNotEmpty) 'hint': hint.trim(),
      }, _aiTimeout);

  Future<Map<String, dynamic>> scanBill(String base64Image, String mime) =>
      ApiClient.I.post('/ai/scan-bill', {'image_base64': base64Image, 'mime_type': mime}, _aiTimeout);
}
