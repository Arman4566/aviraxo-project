import '../../../models/onboarding_data.dart';

enum InvoiceDocType {
  gstInvoice,
  retailInvoice,
  estimate,
  proforma,
  deliveryChallan,
}

class InvoiceDraft {
  InvoiceDocType type;

  // Party / Customer
  Party? party;
  bool cashCustomer = false;

  // Header
  String invoiceNo = ""; // preview only; the server assigns the real number on save
  DateTime date = DateTime.now();

  // Items
  final List<InvoiceLine> lines = [];

  // Optional details
  String notes = "";
  String terms = "";
  String paymentMethod = "Cash"; // Cash, UPI, Card, Bank, Credit
  DateTime? dueDate;

  InvoiceDraft({required this.type});

  bool isGst(OnboardingData onboarding) {
    // If onboarding GST is off → non-GST UI
    if (onboarding.gstRegistered != true) return false;

    // Delivery challan / estimate / proforma may still show GST columns depending on business,
    // but Phase-0: show GST when GST registered and document is gstInvoice OR wholesale mode.
    if (type == InvoiceDocType.gstInvoice) return true;
    if (type == InvoiceDocType.retailInvoice) return false;
    // For others: keep GST visible if GST registered (demo)
    return true;
  }

  bool isRetail(OnboardingData onboarding) {
    final bt = (onboarding.businessType ?? "").toLowerCase();
    return bt == "retailer";
  }

  bool isWholesaleLike(OnboardingData onboarding) {
    final bt = (onboarding.businessType ?? "").toLowerCase();
    return bt == "wholesaler" || bt == "distributor";
  }

  // ---------- UI Demo Totals (simple math, NOT full tax rules) ----------
  double get subtotal {
    double s = 0;
    for (final l in lines) {
      s += l.qty * l.rate;
    }
    return s;
  }

  double get discountTotal {
    double d = 0;
    for (final l in lines) {
      d += l.discountAmount;
    }
    return d;
  }

  double get taxable => (subtotal - discountTotal).clamp(0, double.infinity);

  double taxTotal({required bool gstEnabled}) {
    if (!gstEnabled) return 0;
    double t = 0;
    for (final l in lines) {
      t += l.taxAmount;
    }
    return t;
  }

  double grandTotal({required bool gstEnabled}) {
    return taxable + taxTotal(gstEnabled: gstEnabled);
  }
}

class Party {
  final int id; // server id (0 = unknown)
  final String name;
  final String phone;
  final double outstanding;
  final bool gstRegistered;

  Party({
    this.id = 0,
    required this.name,
    required this.phone,
    required this.outstanding,
    required this.gstRegistered,
  });
}

class CatalogItem {
  final int? itemId; // server item id (null = free-text line, no stock effect)
  final String name;
  final String unit; // pcs, box, kg
  final double rate;
  final int gstSlab; // 0,5,12,18,28
  final String hsn; // optional

  CatalogItem({
    this.itemId,
    required this.name,
    required this.unit,
    required this.rate,
    required this.gstSlab,
    required this.hsn,
  });
}

class InvoiceLine {
  final CatalogItem item;
  int qty;
  double rate;
  bool discountIsPercent;
  double discountValue; // percent OR rupees
  int gstSlab; // from item

  InvoiceLine({
    required this.item,
    this.qty = 1,
    required this.rate,
    this.discountIsPercent = true,
    this.discountValue = 0,
    required this.gstSlab,
  });

  double get lineBase => qty * rate;

  double get discountAmount {
    if (discountValue <= 0) return 0;
    if (discountIsPercent) return lineBase * (discountValue / 100);
    return discountValue.clamp(0, lineBase);
  }

  double get taxable => (lineBase - discountAmount).clamp(0, double.infinity);

  double get taxAmount => taxable * (gstSlab / 100);

  double get lineTotalGst => taxable + taxAmount;

  double lineTotal({required bool gstEnabled}) => gstEnabled ? lineTotalGst : taxable;
}
