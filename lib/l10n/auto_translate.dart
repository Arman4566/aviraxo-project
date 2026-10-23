import '../core/prefs.dart';
import 'hi_phrases.dart';

/// Translates a ready-made English UI string into the app language.
///
/// English stays exactly as written. In Hindi the string is looked up in [hiPhrases] (exact match), then in
/// [hiPatterns] (sentences with numbers/names inside, written with `{0}`, `{1}` for the changing parts).
/// Anything not found is shown in English, so nothing ever goes blank. Results are cached.
final Map<String, String> _cache = {};
List<(RegExp, String)>? _compiled;

String trs(String s) {
  if (s.isEmpty || AppPrefs.I.language.value != 'hi') return s;
  final hit = _cache[s];
  if (hit != null) return hit;
  final out = hiPhrases[s] ?? _fromLong(s) ?? _fromDate(s) ?? _fromPattern(s) ?? s;
  if (_cache.length > 4000) _cache.clear();
  _cache[s] = out;
  return out;
}

const _months = {
  'Jan': 'जनवरी', 'Feb': 'फ़रवरी', 'Mar': 'मार्च', 'Apr': 'अप्रैल', 'May': 'मई', 'Jun': 'जून',
  'Jul': 'जुलाई', 'Aug': 'अगस्त', 'Sep': 'सितंबर', 'Oct': 'अक्टूबर', 'Nov': 'नवंबर', 'Dec': 'दिसंबर',
};
final RegExp _dateLike = RegExp(r'^(\d{1,2} )?(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)( \d{2,4})?$');

/// "5 Oct", "5 Oct 2026", "Oct 2026": month names in Hindi, digits unchanged.
String? _fromDate(String s) {
  final m = _dateLike.firstMatch(s);
  if (m == null) return null;
  return '${m.group(1) ?? ''}${_months[m.group(2)]}${m.group(3) ?? ''}';
}

String? _fromLong(String s) {
  if (s.length < 200) return null;
  for (final e in hiLong.entries) {
    if (s.startsWith(e.key)) return e.value;
  }
  return null;
}

String? _fromPattern(String s) {
  _compiled ??= [
    for (final e in hiPatterns.entries)
      (
        RegExp('^${RegExp.escape(e.key).replaceAllMapped(RegExp(r'\\\{(\d)\\\}'), (m) => '(.+?)').replaceAll(r'\{\}', '(.+?)')}\$', dotAll: true),
        e.value,
      ),
  ];
  for (final (re, hi) in _compiled!) {
    final m = re.firstMatch(s);
    if (m == null) continue;
    var out = hi;
    for (var i = 1; i <= m.groupCount; i++) {
      final part = m.group(i) ?? '';
      out = out.replaceAll('{${i - 1}}', trs(part));
    }
    return out;
  }
  return null;
}
