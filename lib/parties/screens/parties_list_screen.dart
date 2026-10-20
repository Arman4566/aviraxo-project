import 'package:flutter/material.dart';
import '../../theme/gp_colors.dart';
import '../models/party_model.dart';
import '../widgets/party_list_tile.dart';
import '../widgets/party_filters_sheet.dart';

class PartiesListScreen extends StatelessWidget {
  final bool isRetail;
  final List<PartyModel> parties;
  final String search;
  final ValueChanged<String> onSearch;
  final VoidCallback onAdd;
  final ValueChanged<PartyModel> onOpen;

  const PartiesListScreen({
    super.key,
    required this.isRetail,
    required this.parties,
    required this.search,
    required this.onSearch,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = parties.where((p) {
      if (search.isEmpty) return true;
      return p.name.toLowerCase().contains(search.toLowerCase()) ||
          p.phone.contains(search);
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text("Parties",
                        style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => const PartyFiltersSheet(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GPColors.primary,
                      foregroundColor: GPColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Add",
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  )
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: "Search parties",
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(onAdd: onAdd)
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return PartyListTile(
                    party: p,
                    onTap: () => onOpen(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
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
            const Icon(Icons.groups_rounded, size: 44),
            const SizedBox(height: 10),
            const Text("No parties added yet",
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text("Add your first customer or supplier",
                style: TextStyle(color: GPColors.ink2)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onAdd,
              child: const Text("Add Party"),
            )
          ],
        ),
      ),
    );
  }
}
