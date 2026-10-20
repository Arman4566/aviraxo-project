/// Local preferences + onboarding draft, stored as one JSON row in the on-device SQLite database.
class AppSettings {
  // Keep existing behavior
  int id = 0;

  bool onboarded = false;

  /// 0..9 (your PageView index)
  int onboardingStep = 0;

  OnboardingDraft? draft;

  // ============================================================
  // ✅ NEW: App Preferences (Persisted)
  // ============================================================
  String language = "English"; // English / Hindi
  String theme = "System"; // Light / System

  // ============================================================
  // ✅ NEW: Billing & Invoice Settings (Persisted)
  // ============================================================
  bool showItemDiscount = true;
  bool showNotes = true;
  bool showTerms = true;

  /// PDF look: classic, modern or compact.
  String invoiceTemplate = "classic";

  /// Shown on payment reminders as a tap-to-pay UPI link (the server reads settings.upiId).
  String upiId = "";

  // Pricing is from onboardingDraft.pricingStyle, so no extra field here.

  // ============================================================
  // ✅ NEW: Inventory Settings (Persisted)
  // ============================================================
  // (OnboardingDraft has trackInventory/lowStockAlerts/barcodeUsage etc.
  //  but these are onboarding defaults. Settings screen controls "live" settings.)
  bool enableStockTracking = true;
  bool lowStockAlerts = true;
  bool allowNegativeStock = false;

  String defaultUnit = "pcs";
  int defaultGstRate = 18; // 0/5/12/18/28
  bool enableBarcode = false;

  // ============================================================
  // ✅ NEW: Tax Settings (Persisted)
  // ============================================================
  String gstBehavior = "CGST+SGST"; // CGST+SGST / IGST
  bool showGstBreakup = true;
  bool showHsnSac = true;

  // ============================================================
  // ✅ NEW: Notification Settings (Persisted)
  // ============================================================
  bool notifyInvoiceCreated = true;
  bool notifyLowStock = true;

  // Payment module NOT available now — keep but not used
  bool notifyPaymentDue = false;

  int reminderDays = 7;

  DateTime updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'onboardingStep': onboardingStep,
        'draft': draft?.toJson(),
        'language': language,
        'theme': theme,
        'showItemDiscount': showItemDiscount,
        'showNotes': showNotes,
        'showTerms': showTerms,
        'invoiceTemplate': invoiceTemplate,
        'upiId': upiId,
        'enableStockTracking': enableStockTracking,
        'lowStockAlerts': lowStockAlerts,
        'allowNegativeStock': allowNegativeStock,
        'defaultUnit': defaultUnit,
        'defaultGstRate': defaultGstRate,
        'enableBarcode': enableBarcode,
        'gstBehavior': gstBehavior,
        'showGstBreakup': showGstBreakup,
        'showHsnSac': showHsnSac,
        'notifyInvoiceCreated': notifyInvoiceCreated,
        'notifyLowStock': notifyLowStock,
        'notifyPaymentDue': notifyPaymentDue,
        'reminderDays': reminderDays,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  static AppSettings fromJson(Map<String, dynamic> j) {
    final s = AppSettings()..id = 0;
    T g<T>(String k, T d) => j[k] is T ? j[k] as T : d;
    s.onboarded = g('onboarded', false);
    s.onboardingStep = g('onboardingStep', 0);
    s.draft = j['draft'] is Map ? OnboardingDraft.fromJson((j['draft'] as Map).cast<String, dynamic>()) : null;
    s.language = g('language', s.language);
    s.theme = g('theme', s.theme);
    s.showItemDiscount = g('showItemDiscount', s.showItemDiscount);
    s.showNotes = g('showNotes', s.showNotes);
    s.showTerms = g('showTerms', s.showTerms);
    s.invoiceTemplate = g('invoiceTemplate', s.invoiceTemplate);
    s.upiId = g('upiId', s.upiId);
    s.enableStockTracking = g('enableStockTracking', s.enableStockTracking);
    s.lowStockAlerts = g('lowStockAlerts', s.lowStockAlerts);
    s.allowNegativeStock = g('allowNegativeStock', s.allowNegativeStock);
    s.defaultUnit = g('defaultUnit', s.defaultUnit);
    s.defaultGstRate = (j['defaultGstRate'] as num?)?.toInt() ?? s.defaultGstRate;
    s.enableBarcode = g('enableBarcode', s.enableBarcode);
    s.gstBehavior = g('gstBehavior', s.gstBehavior);
    s.showGstBreakup = g('showGstBreakup', s.showGstBreakup);
    s.showHsnSac = g('showHsnSac', s.showHsnSac);
    s.notifyInvoiceCreated = g('notifyInvoiceCreated', s.notifyInvoiceCreated);
    s.notifyLowStock = g('notifyLowStock', s.notifyLowStock);
    s.notifyPaymentDue = g('notifyPaymentDue', s.notifyPaymentDue);
    s.reminderDays = (j['reminderDays'] as num?)?.toInt() ?? s.reminderDays;
    s.updatedAt = DateTime.fromMillisecondsSinceEpoch((j['updatedAt'] as num?)?.toInt() ?? 0);
    return s;
  }
}

class OnboardingDraft {
  String? businessType;

  String? industry;

  bool? gstRegistered;
  String? gstin;
  String gstType = "Within State";
  List<int> gstSlabs = [];

  String? pricingStyle;

  bool? trackInventory;
  bool lowStockAlerts = true;
  bool multipleUnits = false;
  bool barcodeUsage = false;

  List<String> billingDocs = [];
  List<String> paymentMethods = [];

  String? businessName;
  String? address;
  String? state;
  String? pinCode;
  String currency = "INR";

  String? teamSetup;
  List<String> staffRoles = [];

  Map<String, dynamic> toJson() => {
        'businessType': businessType,
        'industry': industry,
        'gstRegistered': gstRegistered,
        'gstin': gstin,
        'gstType': gstType,
        'gstSlabs': gstSlabs,
        'pricingStyle': pricingStyle,
        'trackInventory': trackInventory,
        'lowStockAlerts': lowStockAlerts,
        'multipleUnits': multipleUnits,
        'barcodeUsage': barcodeUsage,
        'billingDocs': billingDocs,
        'paymentMethods': paymentMethods,
        'businessName': businessName,
        'address': address,
        'state': state,
        'pinCode': pinCode,
        'currency': currency,
        'teamSetup': teamSetup,
        'staffRoles': staffRoles,
      };

  static OnboardingDraft fromJson(Map<String, dynamic> j) {
    List<String> strs(String k) => ((j[k] as List?) ?? const []).map((e) => '$e').toList();
    return OnboardingDraft()
      ..businessType = j['businessType'] as String?
      ..industry = j['industry'] as String?
      ..gstRegistered = j['gstRegistered'] as bool?
      ..gstin = j['gstin'] as String?
      ..gstType = (j['gstType'] as String?) ?? 'Within State'
      ..gstSlabs = ((j['gstSlabs'] as List?) ?? const []).map((e) => (e as num).toInt()).toList()
      ..pricingStyle = j['pricingStyle'] as String?
      ..trackInventory = j['trackInventory'] as bool?
      ..lowStockAlerts = (j['lowStockAlerts'] as bool?) ?? true
      ..multipleUnits = (j['multipleUnits'] as bool?) ?? false
      ..barcodeUsage = (j['barcodeUsage'] as bool?) ?? false
      ..billingDocs = strs('billingDocs')
      ..paymentMethods = strs('paymentMethods')
      ..businessName = j['businessName'] as String?
      ..address = j['address'] as String?
      ..state = j['state'] as String?
      ..pinCode = j['pinCode'] as String?
      ..currency = (j['currency'] as String?) ?? 'INR'
      ..teamSetup = j['teamSetup'] as String?
      ..staffRoles = strs('staffRoles');
  }
}
