import '../../core/api_client.dart';
import '../models/app_settings.dart';

/// Maps between the local settings cache (Isar AppSettings) and the server's business record.
///
/// Server columns: name, business_type, industry, gst_registered, gstin, address, state, pincode, currency.
/// Everything else (onboarding answers + app preferences) travels inside business.settings (JSON).
class BusinessSync {
  static Map<String, dynamic> payloadFrom(AppSettings s) {
    final d = s.draft ?? OnboardingDraft();
    final name = (d.businessName ?? '').trim();
    return {
      'name': name.isEmpty ? 'My Business' : name,
      'business_type': d.businessType,
      'industry': d.industry,
      'gst_registered': d.gstRegistered ?? false,
      'gstin': (d.gstin ?? '').trim().isEmpty ? null : d.gstin!.trim(),
      'address': d.address,
      'state': d.state,
      'pincode': d.pinCode,
      'currency': d.currency,
      'settings': {
        // onboarding answers
        'gstType': d.gstType,
        'gstSlabs': d.gstSlabs,
        'pricingStyle': d.pricingStyle,
        'trackInventory': d.trackInventory,
        'lowStockAlerts': d.lowStockAlerts,
        'multipleUnits': d.multipleUnits,
        'barcodeUsage': d.barcodeUsage,
        'billingDocs': d.billingDocs,
        'paymentMethods': d.paymentMethods,
        'teamSetup': d.teamSetup,
        'staffRoles': d.staffRoles,
        // app preferences
        'language': s.language,
        'theme': s.theme,
        'showItemDiscount': s.showItemDiscount,
        'showNotes': s.showNotes,
        'showTerms': s.showTerms,
        'invoiceTemplate': s.invoiceTemplate,
        'upiId': s.upiId.trim(),
        'enableStockTracking': s.enableStockTracking,
        'prefLowStockAlerts': s.lowStockAlerts,
        'allowNegativeStock': s.allowNegativeStock, // the server reads this one when selling
        'defaultUnit': s.defaultUnit,
        'defaultGstRate': s.defaultGstRate,
        'enableBarcode': s.enableBarcode,
        'gstBehavior': s.gstBehavior,
        'showGstBreakup': s.showGstBreakup,
        'showHsnSac': s.showHsnSac,
        'notifyInvoiceCreated': s.notifyInvoiceCreated,
        'notifyLowStock': s.notifyLowStock,
        'notifyPaymentDue': s.notifyPaymentDue,
        'reminderDays': s.reminderDays,
      },
    };
  }

  /// Fills [s] from a server business JSON object.
  static void applyTo(AppSettings s, Map<String, dynamic> b) {
    final cfg = (b['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    T pick<T>(String k, T fallback) => cfg[k] is T ? cfg[k] as T : fallback;
    List<String> strs(String k) => ((cfg[k] as List?) ?? const []).map((e) => '$e').toList();

    s.onboarded = true;
    s.onboardingStep = 8;

    final d = OnboardingDraft()
      ..businessName = b['name'] as String?
      ..businessType = b['business_type'] as String?
      ..industry = b['industry'] as String?
      ..gstRegistered = b['gst_registered'] as bool?
      ..gstin = b['gstin'] as String?
      ..address = b['address'] as String?
      ..state = b['state'] as String?
      ..pinCode = b['pincode'] as String?
      ..currency = (b['currency'] as String?) ?? 'INR'
      ..gstType = pick<String>('gstType', 'Within State')
      ..gstSlabs = ((cfg['gstSlabs'] as List?) ?? const []).map((e) => (e as num).toInt()).toList()
      ..pricingStyle = cfg['pricingStyle'] as String?
      ..trackInventory = cfg['trackInventory'] as bool?
      ..lowStockAlerts = pick<bool>('lowStockAlerts', true)
      ..multipleUnits = pick<bool>('multipleUnits', false)
      ..barcodeUsage = pick<bool>('barcodeUsage', false)
      ..billingDocs = strs('billingDocs')
      ..paymentMethods = strs('paymentMethods')
      ..teamSetup = cfg['teamSetup'] as String?
      ..staffRoles = strs('staffRoles');
    s.draft = d;

    s.language = pick<String>('language', s.language);
    s.theme = pick<String>('theme', s.theme);
    s.showItemDiscount = pick<bool>('showItemDiscount', s.showItemDiscount);
    s.showNotes = pick<bool>('showNotes', s.showNotes);
    s.showTerms = pick<bool>('showTerms', s.showTerms);
    s.enableStockTracking = pick<bool>('enableStockTracking', s.enableStockTracking);
    s.lowStockAlerts = pick<bool>('prefLowStockAlerts', s.lowStockAlerts);
    s.allowNegativeStock = pick<bool>('allowNegativeStock', s.allowNegativeStock);
    s.defaultUnit = pick<String>('defaultUnit', s.defaultUnit);
    s.defaultGstRate = (cfg['defaultGstRate'] as num?)?.toInt() ?? s.defaultGstRate;
    s.enableBarcode = pick<bool>('enableBarcode', s.enableBarcode);
    s.gstBehavior = pick<String>('gstBehavior', s.gstBehavior);
    s.showGstBreakup = pick<bool>('showGstBreakup', s.showGstBreakup);
    s.showHsnSac = pick<bool>('showHsnSac', s.showHsnSac);
    s.notifyInvoiceCreated = pick<bool>('notifyInvoiceCreated', s.notifyInvoiceCreated);
    s.notifyLowStock = pick<bool>('notifyLowStock', s.notifyLowStock);
    s.notifyPaymentDue = pick<bool>('notifyPaymentDue', s.notifyPaymentDue);
    s.reminderDays = (cfg['reminderDays'] as num?)?.toInt() ?? s.reminderDays;
    s.updatedAt = DateTime.now();
  }

  /// Saves the business + settings on the server (creates the business on first call).
  static Future<Map<String, dynamic>> push(AppSettings s) async {
    final r = await ApiClient.I.put('/business', payloadFrom(s));
    return (r['business'] as Map).cast<String, dynamic>();
  }
}
