import 'package:flutter/material.dart' hide Text;
import '../l10n/gtext.dart';

import '../models/onboarding_data.dart';
import '../theme/gp_colors.dart';
import 'invoice_flow/invoice_flow.dart';

import '../data/repositories/invoice_repo.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatelessWidget {
  final OnboardingData data;
  const InvoicesScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final repo = InvoiceRepo();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GPColors.tint.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GPColors.line),
            ),
            child: const Row(
              children: [
                Icon(Icons.receipt_long_rounded),
                SizedBox(width: 10),
                Expanded(
                  child: Text("Invoices", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GPColors.primary,
                foregroundColor: GPColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => InvoiceFlow(onboarding: data)),
                );
              },
              child: const Text("➕ New Invoice", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),

          const SizedBox(height: 14),

          Expanded(
            child: StreamBuilder(
              stream: repo.watchAll(),
              builder: (context, snap) {
                final list = (snap.data ?? []);
                if (list.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: GPColors.tint.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: GPColors.line),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 42),
                          SizedBox(height: 10),
                          Text("No invoices yet", style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text("Create your first invoice to see it here.", style: TextStyle(color: GPColors.ink2)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final inv = list[i];
                    final d = DateTime.fromMillisecondsSinceEpoch(inv.dateMs);
                    final date = "${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}";
                    final party = inv.cashCustomer ? "Cash Customer" : (inv.partyName.isEmpty ? "—" : inv.partyName);

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: inv.id)),
                        );
                        repo.refresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: GPColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: GPColors.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: GPColors.primary.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.description_rounded, color: GPColors.ink),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 4),
                                  Text("$party • $date", style: TextStyle(color: GPColors.ink2)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹${inv.grandTotal.toStringAsFixed(0)}",
                                    style: const TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(
                                  !inv.affectsBooks
                                      ? "Document"
                                      : inv.isOverdue
                                          ? "Overdue ₹${inv.balanceDue.toStringAsFixed(0)}"
                                          : inv.status == "paid"
                                              ? "Paid"
                                              : "Due ₹${inv.balanceDue.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: !inv.affectsBooks
                                        ? GPColors.ink2
                                        : inv.status == "paid"
                                            ? GPColors.success
                                            : Colors.red,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
