import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import '../models/onboarding_data.dart';
import '../theme/gp_colors.dart';
import '../core/prefs.dart';

import '../dashboard/dashboard_screen.dart';
import '../invoices/invoices_screen.dart';
import '../catalog/catalog_screen.dart';
import '../inventory/inventory_screen.dart';
import '../parties/parties_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../receivables/receivables_screen.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/low_stock_screen.dart';
import '../insights/insights_screen.dart';
import '../insights/analytics_screen.dart';
import '../ai/ask_screen.dart';
import '../ai/scan_bill_screen.dart';
import '../reports/finance_reports_screen.dart';
import '../core/outbox.dart';

import '../data/repositories/workspace_repo.dart';
import '../data/models/app_settings.dart';

// ✅ NEW: legal screens
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_conditions_screen.dart';

class BaseScreen extends StatefulWidget {
  /// Keeping this parameter so your existing navigation won’t break.
  /// But UI now uses Isar as source of truth.
  final OnboardingData data;
  const BaseScreen({super.key, required this.data});

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  int _index = 0;
  static Color get _accent => GPColors.primary;

  final _repo = WorkspaceRepo();
  List<_TabItem> _lastTabs = const [];

  /// Switch to a bottom-bar tab by its English name (used by dashboard shortcuts and the side panel).
  void _goTab(String label) {
    final idx = _lastTabs.indexWhere((t) => t.label == trs(label));
    if (idx != -1 && mounted) setState(() => _index = idx);
  }

  bool _isServicesFrom(OnboardingData d) =>
      (d.businessType ?? "").toLowerCase() == "services";

  List<_TabItem> _tabsFor(OnboardingData data) {
    final isServices = _isServicesFrom(data);

    final items = <_TabItem>[
      _TabItem(
        label: trs("Dashboard"),
        iconOutlined: Icons.home_outlined,
        iconFilled: Icons.home_rounded,
        screen: DashboardScreen(data: data, onOpenTab: _goTab),
      ),
      _TabItem(
        label: trs("Invoices"),
        iconOutlined: Icons.receipt_long_outlined,
        iconFilled: Icons.receipt_long_rounded,
        screen: InvoicesScreen(data: data),
      ),
      if (!isServices)
        _TabItem(
          label: trs("Catalog"),
          iconOutlined: Icons.storefront_outlined,
          iconFilled: Icons.storefront_rounded,
          screen: CatalogScreen(data: data),
        ),
      if (!isServices)
        _TabItem(
          label: trs("Inventory"),
          iconOutlined: Icons.inventory_2_outlined,
          iconFilled: Icons.inventory_2_rounded,
          screen: InventoryScreen(data: data),
        ),
      _TabItem(
        label: trs("Parties"),
        iconOutlined: Icons.groups_outlined,
        iconFilled: Icons.groups_rounded,
        screen: PartiesScreen(data: data),
      ),
      _TabItem(
        label: trs("Reports"),
        iconOutlined: Icons.bar_chart_outlined,
        iconFilled: Icons.bar_chart_rounded,
        screen: ReportsScreen(data: data),
      ),
    ];

    if (_index >= items.length) _index = 0;
    return items;
  }

  void _openSettings(OnboardingData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(data: data),
      ),
    );
  }

  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _openTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
    );
  }

  void _openContactPopup() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          "Contact",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const SelectableText("example@gmail.com"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppSettings?>(
      stream: _repo.watchSettings(),
      builder: (context, snap) {
        // If settings not ready, fall back to the passed data so app never crashes.
        final data = snap.data == null
            ? widget.data
            : OnboardingData.fromDraft(snap.data!.draft);

        final isServices = _isServicesFrom(data);
        final tabs = _tabsFor(data);
        _lastTabs = tabs;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            foregroundColor: GPColors.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            // Frosted bar: blurs and tints whatever scrolls under it.
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: GPColors.surface, border: Border(bottom: BorderSide(color: GPColors.glassEdge))),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            centerTitle: true,
            title: const Text(
              "Galla Pro",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            actions: [
              // Waiting-to-sync badge: shows how many offline entries are still on this phone.
              ValueListenableBuilder<int>(
                valueListenable: Outbox.I.pending,
                builder: (context, n, _) => n == 0
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: trs("$n waiting to sync"),
                        icon: Badge(label: Text("$n"), child: const Icon(Icons.cloud_upload_outlined)),
                        onPressed: () async {
                          final sent = await Outbox.I.flush();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(sent > 0 ? "$sent entries synced" : "Still offline. We will retry automatically.")),
                          );
                        },
                      ),
              ),
              IconButton(
                tooltip: trs("Payment reminders"),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceivablesScreen(initialTab: 2))),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              IconButton(
                tooltip: trs("Settings"),
                onPressed: () => _openSettings(data),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          drawer: _AppDrawer(
            accent: _accent,
            isServices: isServices,
            onNavigate: (routeLabel) {
              Navigator.pop(context);

              // ✅ NEW drawer actions
              if (routeLabel == "Privacy Policy") {
                _openPrivacyPolicy();
                return;
              }
              if (routeLabel == "Terms & Conditions") {
                _openTerms();
                return;
              }
              if (routeLabel == "Contact") {
                _openContactPopup();
                return;
              }

              // ✅ Keep existing navigation working
              if (routeLabel == "Settings") {
                _openSettings(data);
                return;
              }

              final extra = <String, Widget>{
                "Collect Payments": const ReceivablesScreen(),
                "Analytics": const AnalyticsScreen(),
                "Ask AI": const AskScreen(),
                "Scan Bill (AI)": const ScanBillScreen(),
                "Expenses": const ExpensesScreen(),
                "Insights & Forecast": const InsightsScreen(),
                "Low Stock": const LowStockScreen(),
                "Profit, Cash & GST": const FinanceReportsScreen(),
              };
              if (extra.containsKey(routeLabel)) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => extra[routeLabel]!));
                return;
              }

              final idx = tabs.indexWhere((t) => t.label == trs(routeLabel));
              if (idx != -1) {
                setState(() => _index = idx);
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$routeLabel (coming soon)")),
              );
            },
          ),
          body: IndexedStack(
            index: _index,
            children: tabs.map((t) => t.screen).toList(),
          ),
          bottomNavigationBar: Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ClipRect(
              child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
              decoration: BoxDecoration(
                color: GPColors.surface,
                border: Border(top: BorderSide(color: GPColors.glassEdge)),
              ),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                type: BottomNavigationBarType.fixed,
                selectedItemColor: _accent,
                unselectedItemColor: GPColors.ink2,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIconTheme: const IconThemeData(size: 24),
                unselectedIconTheme: const IconThemeData(size: 24),
                selectedLabelStyle: const TextStyle(fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                items: [
                  for (int i = 0; i < tabs.length; i++)
                    BottomNavigationBarItem(
                      icon: Icon(
                        i == _index ? tabs[i].iconFilled : tabs[i].iconOutlined,
                      ),
                      label: trs(tabs[i].label),
                    ),
                ],
              ),
            ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabItem {
  final String label;
  final IconData iconOutlined;
  final IconData iconFilled;
  final Widget screen;

  _TabItem({
    required this.label,
    required this.iconOutlined,
    required this.iconFilled,
    required this.screen,
  });
}

class _AppDrawer extends StatelessWidget {
  final bool isServices;
  final void Function(String label) onNavigate;
  final Color accent;

  const _AppDrawer({
    required this.isServices,
    required this.onNavigate,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;

    final items = <_DrawerItem>[
      _DrawerItem("Dashboard", Icons.home_rounded),
      _DrawerItem("Invoices", Icons.receipt_long_rounded),
      if (!isServices) _DrawerItem("Catalog", Icons.storefront_rounded),
      if (!isServices) _DrawerItem("Inventory", Icons.inventory_2_rounded),
      _DrawerItem("Parties", Icons.groups_rounded),
      _DrawerItem("Reports", Icons.bar_chart_rounded),
      _DrawerItem("Analytics", Icons.insights_rounded),
      _DrawerItem("Ask AI", Icons.auto_awesome_rounded),
      if (!isServices) _DrawerItem("Scan Bill (AI)", Icons.document_scanner_rounded),
      _DrawerItem("Collect Payments", Icons.account_balance_wallet_rounded),
      _DrawerItem("Settings", Icons.settings_rounded),
    ];

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, statusBar + 16, 16, 16),
            decoration: BoxDecoration(
              color: accent,
              border: Border(bottom: BorderSide(color: GPColors.line)),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/galla_pro.png', width: 46, height: 46, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Galla Pro",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Inventory & Billing Software",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )),
            ]),
          ),
          // Quick switches: language and light/dark.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: AppPrefs.I.language,
                  builder: (_, lang, __) => SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'hi', label: Text('हिन्दी')),
                    ],
                    selected: {lang},
                    onSelectionChanged: (v) => AppPrefs.I.setLanguage(v.first),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppPrefs.I.themeMode,
                builder: (_, mode, __) => IconButton.filledTonal(
                  tooltip: trs('Theme'),
                  onPressed: () => AppPrefs.I.setThemeMode(GPColors.dark ? ThemeMode.light : ThemeMode.dark),
                  icon: Icon(GPColors.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return ListTile(
                  leading: Icon(it.icon),
                  title: Text(
                    it.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onTap: () => onNavigate(it.label),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;
  _DrawerItem(this.label, this.icon);
}
