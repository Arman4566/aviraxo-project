import '../../core/money.dart';

/// A customer / supplier as returned by the server.
class PartyEntity {
  int id = 0;

  String name = '';
  String phone = '';
  String email = '';

  /// "customer" | "supplier" | "both"
  String type = 'customer';

  // GST
  bool gstRegistered = false;
  String gstin = '';
  String state = '';
  String billingAddress = '';
  String shippingAddress = '';

  // Credit
  double openingBalance = 0;
  bool toReceive = true; // true = party owes us
  double creditLimit = 0;
  String paymentTerm = 'Immediate';

  /// LIVE balance from the ledger: opening + invoices - payments. Positive = party owes us.
  double balance = 0;

  // meta
  int lastTxnMs = 0;
  int createdAtMs = 0;
  int updatedAtMs = 0;

  PartyEntity();

  factory PartyEntity.fromJson(Map<String, dynamic> j) {
    int ms(dynamic v) => DateTime.tryParse('$v')?.millisecondsSinceEpoch ?? 0;
    final p = PartyEntity();
    p.id = (j['id'] as num).toInt();
    p.name = (j['name'] ?? '') as String;
    p.phone = (j['phone'] ?? '') as String;
    p.email = (j['email'] ?? '') as String;
    p.type = (j['type'] ?? 'customer') as String;
    p.gstRegistered = (j['gst_registered'] ?? false) as bool;
    p.gstin = (j['gstin'] ?? '') as String;
    p.state = (j['state'] ?? '') as String;
    p.billingAddress = (j['billing_address'] ?? '') as String;
    p.shippingAddress = (j['shipping_address'] ?? '') as String;
    p.openingBalance = toRupees((j['opening_balance'] ?? 0) as num);
    p.toReceive = (j['to_receive'] ?? true) as bool;
    p.creditLimit = toRupees((j['credit_limit'] ?? 0) as num);
    p.paymentTerm = (j['payment_term'] ?? 'Immediate') as String;
    p.balance = toRupees((j['balance'] ?? 0) as num);
    p.lastTxnMs = ms(j['last_txn_at']);
    p.createdAtMs = ms(j['created_at']);
    p.updatedAtMs = ms(j['updated_at']);
    return p;
  }

  Map<String, dynamic> toApi() => {
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'type': type,
        'gst_registered': gstRegistered,
        'gstin': gstin.trim(),
        'state': state.trim(),
        'billing_address': billingAddress,
        'shipping_address': shippingAddress,
        'opening_balance': toPaise(openingBalance.abs()),
        'to_receive': toReceive,
        'credit_limit': toPaise(creditLimit),
        'payment_term': paymentTerm,
      };
}

/// One row of a party statement.
class LedgerEntry {
  LedgerEntry({
    required this.date,
    required this.type,
    required this.ref,
    required this.id,
    required this.status,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final DateTime date;

  /// "invoice" | "payment"
  final String type;
  final String ref;
  final int id;
  final String status;
  final double debit; // invoice amount
  final double credit; // payment received
  final double balance; // running balance after this row (positive = party owes us)

  bool get isInvoice => type == 'invoice';

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        date: DateTime.tryParse('${j['date']}'.substring(0, 10)) ?? DateTime.now(),
        type: (j['type'] ?? '') as String,
        ref: (j['ref'] ?? '') as String,
        id: (j['id'] as num).toInt(),
        status: (j['status'] ?? '') as String,
        debit: toRupees((j['debit'] ?? 0) as num),
        credit: toRupees((j['credit'] ?? 0) as num),
        balance: toRupees((j['balance'] ?? 0) as num),
      );
}

class PartyLedger {
  PartyLedger({required this.openingBalance, required this.entries, required this.closingBalance});
  final double openingBalance;
  final List<LedgerEntry> entries;
  final double closingBalance;

  factory PartyLedger.fromJson(Map<String, dynamic> j) => PartyLedger(
        openingBalance: toRupees((j['opening_balance'] ?? 0) as num),
        entries: ((j['entries'] as List?) ?? const [])
            .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        closingBalance: toRupees((j['closing_balance'] ?? 0) as num),
      );
}
