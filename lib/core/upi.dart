/// UPI "pay now" link, the same format every UPI app understands (and what a UPI QR code contains).
/// [amount] is in rupees. Returns '' when there is no UPI ID.
String upiPayUrl({required String upiId, required String payeeName, double? amount, String? note}) {
  final id = upiId.trim();
  if (id.isEmpty) return '';
  final q = <String, String>{
    'pa': id,
    if (payeeName.trim().isNotEmpty) 'pn': payeeName.trim(),
    if (amount != null && amount > 0) 'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    if (note != null && note.trim().isNotEmpty) 'tn': note.trim(),
  };
  return 'upi://pay?${q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
}
