import 'package:flutter/material.dart';
import '../models/onboarding_data.dart';
import '../data/repositories/party_repo.dart';
import '../data/models/party_entity.dart';

import 'models/party_model.dart';
import 'screens/parties_list_screen.dart';
import 'screens/add_edit_party_flow.dart';
import 'screens/party_detail_screen.dart';

class PartiesScreen extends StatefulWidget {
  final OnboardingData data;
  const PartiesScreen({super.key, required this.data});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  final _repo = PartyRepo();
  String _search = "";

  bool get _isRetail =>
      (widget.data.businessType ?? "").toLowerCase() == "retailer";

  void _addParty() async {
    final p = await Navigator.push<PartyModel>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditPartyFlow(initial: null)),
    );
    if (p != null) {
      // Stream will update automatically; no need setState on list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${p.name} saved")),
      );
    }
  }

  void _openParty(PartyModel p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PartyDetailScreen(partyId: p.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PartyEntity>>(
      stream: _repo.watchAll(),
      builder: (context, snap) {
        final entities = snap.data ?? [];
        final parties = entities.map(PartyModel.fromEntity).toList();

        return PartiesListScreen(
          isRetail: _isRetail,
          parties: parties,
          search: _search,
          onSearch: (v) => setState(() => _search = v),
          onAdd: _addParty,
          onOpen: _openParty,
        );
      },
    );
  }
}
