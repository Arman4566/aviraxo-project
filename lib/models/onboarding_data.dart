import '../data/models/app_settings.dart';

class OnboardingData {
  // Screen 1
  String? businessType;

  // Screen 2
  String? industry;

  // Screen 3
  bool? gstRegistered;
  String? gstin;
  String gstType = "Within State";
  final Set<int> gstSlabs = {};

  // Screen 4
  String? pricingStyle;

  // Screen 5
  bool? trackInventory;
  bool lowStockAlerts = true;
  bool multipleUnits = false;
  bool barcodeUsage = false;

  // Screen 6
  final Set<String> billingDocs = {};
  final Set<String> paymentMethods = {};

  // Screen 7
  String? businessName;
  String? address;
  String? state;
  String? pinCode;
  String currency = "INR";

  // Screen 8
  String? teamSetup;
  final Set<String> staffRoles = {};

  void reset() {
    businessType = null;
    industry = null;
    gstRegistered = null;
    gstin = null;
    gstType = "Within State";
    gstSlabs.clear();
    pricingStyle = null;
    trackInventory = null;
    lowStockAlerts = true;
    multipleUnits = false;
    barcodeUsage = false;
    billingDocs.clear();
    paymentMethods.clear();
    businessName = null;
    address = null;
    state = null;
    pinCode = null;
    currency = "INR";
    teamSetup = null;
    staffRoles.clear();
  }

  /// ✅ Convert UI model -> Isar embedded model
  OnboardingDraft toDraft() {
    return OnboardingDraft()
      ..businessType = businessType
      ..industry = industry
      ..gstRegistered = gstRegistered
      ..gstin = gstin
      ..gstType = gstType
      ..gstSlabs = gstSlabs.toList()
      ..pricingStyle = pricingStyle
      ..trackInventory = trackInventory
      ..lowStockAlerts = lowStockAlerts
      ..multipleUnits = multipleUnits
      ..barcodeUsage = barcodeUsage
      ..billingDocs = billingDocs.toList()
      ..paymentMethods = paymentMethods.toList()
      ..businessName = businessName
      ..address = address
      ..state = state
      ..pinCode = pinCode
      ..currency = currency
      ..teamSetup = teamSetup
      ..staffRoles = staffRoles.toList();
  }

  /// ✅ Convert Isar embedded -> UI model
  static OnboardingData fromDraft(OnboardingDraft? d) {
    final o = OnboardingData();
    if (d == null) return o;

    o.businessType = d.businessType;
    o.industry = d.industry;
    o.gstRegistered = d.gstRegistered;
    o.gstin = d.gstin;
    o.gstType = d.gstType;
    o.gstSlabs.addAll(d.gstSlabs);

    o.pricingStyle = d.pricingStyle;

    o.trackInventory = d.trackInventory;
    o.lowStockAlerts = d.lowStockAlerts;
    o.multipleUnits = d.multipleUnits;
    o.barcodeUsage = d.barcodeUsage;

    o.billingDocs.addAll(d.billingDocs);
    o.paymentMethods.addAll(d.paymentMethods);

    o.businessName = d.businessName;
    o.address = d.address;
    o.state = d.state;
    o.pinCode = d.pinCode;
    o.currency = d.currency;

    o.teamSetup = d.teamSetup;
    o.staffRoles.addAll(d.staffRoles);

    return o;
  }
}
