import '../../data/models/party_entity.dart';

enum PartyType { customer, supplier, both }

class PartyModel {
  final int id;

  String name;
  String phone;
  String email;
  PartyType type;

  // GST
  bool gstRegistered;
  String gstin;
  String state;
  String billingAddress;
  String shippingAddress;

  // Credit
  double openingBalance;
  bool toReceive; // true = customer owes us
  double creditLimit;
  String paymentTerm;

  DateTime lastTxn;

  /// LIVE balance from the server ledger (opening + invoices - payments). Positive = party owes us.
  final double balance;

  PartyModel({
    this.balance = 0,
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.type,
    required this.gstRegistered,
    required this.gstin,
    required this.state,
    required this.billingAddress,
    required this.shippingAddress,
    required this.openingBalance,
    required this.toReceive,
    required this.creditLimit,
    required this.paymentTerm,
    required this.lastTxn,
  });

  bool get hasDue => balance > 0.005;

  String get balanceLabel {
    if (balance.abs() < 0.005) return "No Dues";
    return balance > 0
        ? "Due ₹${balance.toStringAsFixed(0)}"
        : "Advance ₹${(-balance).toStringAsFixed(0)}";
  }

  // ---------- Mapping ----------
  static PartyType _typeFrom(String s) {
    switch (s) {
      case "supplier":
        return PartyType.supplier;
      case "both":
        return PartyType.both;
      default:
        return PartyType.customer;
    }
  }

  static String _typeTo(PartyType t) => t.name;

  static PartyModel fromEntity(PartyEntity e) {
    return PartyModel(
      id: e.id,
      balance: e.balance,
      name: e.name,
      phone: e.phone,
      email: e.email,
      type: _typeFrom(e.type),
      gstRegistered: e.gstRegistered,
      gstin: e.gstin,
      state: e.state,
      billingAddress: e.billingAddress,
      shippingAddress: e.shippingAddress,
      openingBalance: e.openingBalance,
      toReceive: e.toReceive,
      creditLimit: e.creditLimit,
      paymentTerm: e.paymentTerm,
      lastTxn: DateTime.fromMillisecondsSinceEpoch(
        e.lastTxnMs == 0 ? DateTime.now().millisecondsSinceEpoch : e.lastTxnMs,
      ),
    );
  }

  /// ✅ Convert UI model -> Entity
  /// IMPORTANT:
  /// - If id == 0 (new party), we DO NOT set entity.id here.
  /// - the server assigns the id
  PartyEntity toEntity({PartyEntity? base}) {
    final e = base ?? PartyEntity();

    // ✅ Only set id when editing existing
    if (id != 0) {
      e.id = id;
    }

    e.name = name;
    e.phone = phone;
    e.email = email;

    e.type = _typeTo(type);

    e.gstRegistered = gstRegistered;
    e.gstin = gstin;
    e.state = state;
    e.billingAddress = billingAddress;
    e.shippingAddress = shippingAddress;

    e.openingBalance = openingBalance;
    e.toReceive = toReceive;
    e.creditLimit = creditLimit;
    e.paymentTerm = paymentTerm;

    e.lastTxnMs = lastTxn.millisecondsSinceEpoch;

    return e;
  }
}
