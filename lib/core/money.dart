/// The server stores money as integer paise. The app works in rupees (double) on screen.
int toPaise(num rupees) => (rupees * 100).round();
double toRupees(num paise) => paise / 100.0;

/// Formats paise as rupees with Indian digit grouping: 123456789 paise -> ₹12,34,567.89 (decimals only when needed).
String inr(num paise, {bool symbol = true}) {
  final neg = paise < 0;
  final abs = paise.abs().round();
  final rupees = abs ~/ 100;
  final p = abs % 100;
  var s = rupees.toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  final dec = p == 0 ? '' : '.${p.toString().padLeft(2, '0')}';
  return '${neg ? '-' : ''}${symbol ? '₹' : ''}$s$dec';
}

/// Short rupee text for chart labels and tight tiles: ₹950, ₹12.5k, ₹3.2L (lakh), ₹1.4Cr (crore).
String compactInr(num paise) {
  final r = paise / 100;
  final a = r.abs();
  String f(double v) => v >= 100 || v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  final sign = r < 0 ? '-' : '';
  if (a >= 10000000) return '$sign₹${f(a / 10000000)}Cr';
  if (a >= 100000) return '$sign₹${f(a / 100000)}L';
  if (a >= 1000) return '$sign₹${f(a / 1000)}k';
  return '$sign₹${a.round()}';
}
