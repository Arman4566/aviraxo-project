import 'package:flutter/material.dart';
import '../../models/onboarding_data.dart';
import 'models/invoice_draft.dart';
import '../../data/repositories/invoice_repo.dart';
import 'screens/inv_type_screen.dart';
import 'screens/inv_party_screen.dart';
import 'screens/inv_items_screen.dart';
import 'screens/inv_preview_screen.dart';
import 'screens/inv_success_screen.dart';

class InvoiceFlow extends StatefulWidget {
  final OnboardingData onboarding;

  /// Optional: start the invoice already addressed to this customer (e.g. from the party screen).
  final Party? initialParty;
  const InvoiceFlow({super.key, required this.onboarding, this.initialParty});

  @override
  State<InvoiceFlow> createState() => _InvoiceFlowState();
}

class _InvoiceFlowState extends State<InvoiceFlow> {
  late InvoiceDraft draft;
  final _page = PageController();
  int _index = 0;

  // ✅ store saved invoice id to show on success screen
  int? _savedInvoiceId;

  @override
  void initState() {
    super.initState();

    // Smart default based on onboarding
    final gst = widget.onboarding.gstRegistered == true;
    final bt = (widget.onboarding.businessType ?? "").toLowerCase();

    InvoiceDocType defaultType;
    if (bt == "retailer") {
      defaultType = InvoiceDocType.retailInvoice;
    } else if (gst) {
      defaultType = InvoiceDocType.gstInvoice;
    } else {
      defaultType = InvoiceDocType.retailInvoice;
    }

    draft = InvoiceDraft(type: defaultType);
    if (widget.initialParty != null) draft.party = widget.initialParty;
  }

  /// Preview of the number the server will assign (the real one is given on save).
  Future<void> _loadNextNumber() async {
    try {
      final no = await InvoiceRepo().nextInvoiceNo(draft.type);
      if (mounted) setState(() => draft.invoiceNo = no);
    } catch (_) {
      // not critical: the number is assigned by the server anyway
    }
  }

  void go(int i) {
    if (i >= 2) _loadNextNumber();
    setState(() => _index = i);
    _page.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  void next() {
    if (_index < 4) go(_index + 1);
  }

  void back() {
    if (_index > 0) go(_index - 1);
    else Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            InvTypeScreen(
              onboarding: widget.onboarding,
              draft: draft,
              onContinue: () => next(),
              onBack: back,
            ),
            InvPartyScreen(
              onboarding: widget.onboarding,
              draft: draft,
              onContinue: () => next(),
              onBack: back,
            ),
            InvItemsScreen(
              onboarding: widget.onboarding,
              draft: draft,
              onContinue: () => next(), // goes to preview
              onBack: back,
            ),
            InvPreviewScreen(
              onboarding: widget.onboarding,
              draft: draft,
              onEdit: () => go(2),
              onSave: (invoiceId) {
                // ✅ InvPreviewScreen now should pass invoiceId when saved
                _savedInvoiceId = invoiceId;
                next();
              },
              onBack: back,
            ),

            // ✅ FIX: remove onboarding: named parameter
            InvSuccessScreen(
              invoiceId: _savedInvoiceId ?? 0,
              onCreateNew: () {
                Navigator.pop(context);
              },
              onGoDashboard: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
