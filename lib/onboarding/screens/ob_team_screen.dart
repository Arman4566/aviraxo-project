import 'package:flutter/material.dart' hide Text;
import '../../l10n/gtext.dart';
import '../../models/onboarding_data.dart';
import '../../widgets/gp_app_bar.dart';
import '../../widgets/gp_buttons.dart';
import '../../widgets/gp_cards.dart';
import '../../theme/gp_colors.dart';

class OBTeamScreen extends StatefulWidget {
  final OnboardingData data;
  final String stepLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  const OBTeamScreen({
    super.key,
    required this.data,
    required this.stepLabel,
    required this.onBack,
    required this.onSkip,
    required this.onFinish,
  });

  @override
  State<OBTeamScreen> createState() => _OBTeamScreenState();
}

class _OBTeamScreenState extends State<OBTeamScreen> {
  void select(String v) {
    setState(() {
      widget.data.teamSetup = v;
      if (v == "Only me") widget.data.staffRoles.clear();
    });
  }

  void toggleRole(String r) {
    setState(() {
      if (widget.data.staffRoles.contains(r)) {
        widget.data.staffRoles.remove(r);
      } else {
        widget.data.staffRoles.add(r);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.data.teamSetup;
    final roles = ["Admin", "Manager", "Cashier", "Accountant"];

    return Column(
      children: [
        GPAppBar(stepLabel: widget.stepLabel, onBack: widget.onBack, onSkip: widget.onSkip),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: ListView(
              children: [
                Text("Who will use Galla Pro?",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),

                GPOptionCard(
                  title: "Only me",
                  subtitle: "Single user workspace",
                  icon: Icons.person_rounded,
                  selected: sel == "Only me",
                  onTap: () => select("Only me"),
                ),
                const SizedBox(height: 10),
                GPOptionCard(
                  title: "Me + staff",
                  subtitle: "Assign roles to your team",
                  icon: Icons.groups_rounded,
                  selected: sel == "Me + staff",
                  onTap: () => select("Me + staff"),
                ),

                const SizedBox(height: 14),

                if (sel == "Me + staff") ...[
                  Text("Select roles (demo)",
                      style: TextStyle(fontWeight: FontWeight.w900, color: GPColors.ink)),
                  const SizedBox(height: 10),
                  ...roles.map((r) {
                    final selected = widget.data.staffRoles.contains(r);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GPOptionCard(
                        title: r,
                        subtitle: "Tap to ${selected ? "remove" : "add"}",
                        icon: Icons.badge_rounded,
                        selected: selected,
                        onTap: () => toggleRole(r),
                      ),
                    );
                  }),
                  Text(
                    "You can invite staff any time from Settings > Users & Roles.",
                    style: TextStyle(color: GPColors.ink2),
                  )
                ],

                const SizedBox(height: 18),
                GPPrimaryButton(text: "Finish Setup", onPressed: widget.onFinish),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
