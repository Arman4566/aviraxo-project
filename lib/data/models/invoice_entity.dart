import '../../core/money.dart';

DateTime _day(dynamic v) {
  final s = '$v';
  final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
  return d ?? DateTime.now();
}

/// An invoice (or estimate / challan) as returned by the server. All totals are in rupees.
class InvoiceEntity {
  int id = 0;

  String invoiceNo = '';
  int dateMs = 0;
  String docType = 'gstInvoice';

  // Seller snapshot
  String businessName = '';
  String businessPhone = '';
  String businessAddress = '';
  String gstin = '';
  String state = '';
  String currency = 'INR';

  // Buyer snapshot
  int? partyId;
  String partyName = '';
  String partyPhone = '';
  bool partyGstRegistered = false;
  bool cashCustomer = false;

  // Payment
  String paymentMethod = 'Cash';
  int? dueDateMs;

  String notes = '';
  String terms = '';

  // Totals
  double subtotal = 0;
  double discountTotal = 0;
  double taxable = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;
  double taxTotal = 0;
  double grandTotal = 0;
  double amountPaid = 0;
  double balanceDue = 0;

  /// open | unpaid | partial | paid | cancelled
  String status = 'paid';
  bool gstEnabled = false;
  bool isInterstate = false;
  String cancelReason = '';

  List<InvoiceLineEntity> lines = [];
  List<InvoicePaymentEntity> payments = [];

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMs);
  bool get isCancelled => status == 'cancelled';
  bool get affectsBooks => docType == 'gstInvoice' || docType == 'retailInvoice';
  bool get isOverdue =>
      dueDateMs != null &&
      (status == 'unpaid' || status == 'partial') &&
      DateTime.fromMillisecondsSinceEpoch(dueDateMs!).isBefore(DateTime.now().subtract(const Duration(days: 1)));

  InvoiceEntity();

  factory InvoiceEntity.fromJson(Map<String, dynamic> j) {
    final e = InvoiceEntity();
    double r(String k) => toRupees((j[k] ?? 0) as num);
    e.id = (j['id'] as num).toInt();
    e.invoiceNo = (j['invoice_no'] ?? '') as String;
    e.dateMs = _day(j['invoice_date']).millisecondsSinceEpoch;
    e.docType = (j['doc_type'] ?? 'gstInvoice') as String;
    e.businessName = (j['business_name'] ?? '') as String;
    e.businessAddress = (j['business_address'] ?? '') as String;
    e.gstin = (j['business_gstin'] ?? '') as String;
    e.state = (j['business_state'] ?? '') as String;
    e.currency = (j['currency'] ?? 'INR') as String;
    e.partyId = (j['party_id'] as num?)?.toInt();
    e.partyName = (j['party_name'] ?? '') as String;
    e.partyPhone = (j['party_phone'] ?? '') as String;
    e.partyGstRegistered = (j['party_gst_registered'] ?? false) as bool;
    e.cashCustomer = (j['cash_customer'] ?? false) as bool;
    e.paymentMethod = (j['payment_method'] ?? 'Cash') as String;
    e.dueDateMs = j['due_date'] == null ? null : _day(j['due_date']).millisecondsSinceEpoch;
    e.notes = (j['notes'] ?? '') as String;
    e.terms = (j['terms'] ?? '') as String;
    e.subtotal = r('subtotal');
    e.discountTotal = r('discount_total');
    e.taxable = r('taxable_value');
    e.cgst = r('cgst');
    e.sgst = r('sgst');
    e.igst = r('igst');
    e.taxTotal = r('tax_total');
    e.grandTotal = r('grand_total');
    e.amountPaid = r('amount_paid');
    e.balanceDue = r('balance_due');
    e.status = (j['status'] ?? 'paid') as String;
    e.gstEnabled = (j['gst_enabled'] ?? false) as bool;
    e.isInterstate = (j['is_interstate'] ?? false) as bool;
    e.cancelReason = (j['cancel_reason'] ?? '') as String;
    e.lines = ((j['lines'] as List?) ?? const [])
        .map((x) => InvoiceLineEntity.fromJson(x as Map<String, dynamic>))
        .toList();
    e.payments = ((j['payments'] as List?) ?? const [])
        .map((x) => InvoicePaymentEntity.fromJson(x as Map<String, dynamic>))
        .toList();
    return e;
  }
}

class InvoiceLineEntity {
  int id = 0;

  String name = '';
  String unit = '';
  String hsn = '';
  int gstSlab = 0;

  int qty = 0;
  double rate = 0;
  bool discountIsPercent = true;
  double discountValue = 0;

  double lineBase = 0;
  double discountAmount = 0;
  double lineTaxable = 0;
  double taxAmount = 0;
  double cgst = 0;
  double sgst = 0;
  double igst = 0;
  double lineTotal = 0;

  InvoiceLineEntity();

  factory InvoiceLineEntity.fromJson(Map<String, dynamic> j) {
    double r(String k) => toRupees((j[k] ?? 0) as num);
    final l = InvoiceLineEntity();
    l.id = (j['id'] as num?)?.toInt() ?? 0;
    l.name = (j['name'] ?? '') as String;
    l.unit = (j['unit'] ?? '') as String;
    l.hsn = (j['hsn'] ?? '') as String;
    l.gstSlab = ((j['gst_slab'] ?? 0) as num).round();
    l.qty = ((j['qty'] ?? 0) as num).round();
    l.rate = r('rate');
    l.discountIsPercent = (j['discount_is_percent'] ?? true) as bool;
    // percent stays a percent; a flat discount is stored in paise
    final dv = (j['discount_value'] ?? 0) as num;
    l.discountValue = l.discountIsPercent ? dv.toDouble() : toRupees(dv);
    l.lineBase = r('line_base');
    l.discountAmount = r('discount_amount');
    l.lineTaxable = r('taxable_value');
    l.taxAmount = r('tax_amount');
    l.cgst = r('cgst');
    l.sgst = r('sgst');
    l.igst = r('igst');
    l.lineTotal = r('line_total');
    return l;
  }
}

/// A payment applied to an invoice.
class InvoicePaymentEntity {
  int id = 0;
  DateTime date = DateTime.now();
  String mode = 'cash';
  String referenceNo = '';
  double amount = 0;

  InvoicePaymentEntity();

  factory InvoicePaymentEntity.fromJson(Map<String, dynamic> j) {
    final p = InvoicePaymentEntity();
    p.id = (j['id'] as num).toInt();
    p.date = _day(j['payment_date']);
    p.mode = (j['mode'] ?? 'cash') as String;
    p.referenceNo = (j['reference_no'] ?? '') as String;
    p.amount = toRupees((j['amount'] ?? 0) as num);
    return p;
  }
}
