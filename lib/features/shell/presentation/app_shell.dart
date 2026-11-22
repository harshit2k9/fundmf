import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/risk_disclaimer.dart';
import '../../auth/presentation/session_providers.dart';
import '../../portfolio/presentation/dashboard_screen.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';

/// Investor navigation shell: bottom bar on phones, rail on tablet/desktop.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Dashboard',
    'Transactions',
    'Profile',
  ];

  static const List<Widget> _pages = <Widget>[
    DashboardScreen(),
    TransactionsScreen(),
    ProfileScreen(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.pie_chart_outline_rounded),
      selectedIcon: Icon(Icons.pie_chart_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Transactions',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  void _refresh() {
    ref.invalidate(transactionFeedProvider);
    ref.invalidate(portfolioSummaryProvider);
  }

  Future<void> _signOut() => ref.read(authRepositoryProvider).signOut();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final profile = ref.watch(activeProfileProvider);

    final actions = <Widget>[
      IconButton(
        tooltip: 'Refresh portfolio',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh_rounded, size: 21),
      ),
      PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: (value) {
          if (value == 'refresh') _refresh();
          if (value == 'signout') _signOut();
        },
        itemBuilder: (context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'refresh',
            child: Text('Refresh data'),
          ),
          PopupMenuItem<String>(
            value: 'signout',
            child: Text('Sign out'),
          ),
        ],
      ),
    ];

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_index]),
          actions: actions,
        ),
        body: Row(
          children: <Widget>[
            NavigationRail(
              extended: width >= 1200,
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.emeraldWash,
              labelType: width >= 1200
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.pie_chart_outline_rounded),
                  selectedIcon: Icon(Icons.pie_chart_rounded),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: Text('Transactions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: IndexedStack(index: _index, children: _pages),
                  ),
                  const _ShellFooter(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const Text(AppConstants.appName),
            const SizedBox(width: 10),
            if (profile != null)
              Text(
                '·  ${profile.fullName.split(' ').first}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.slate,
                ),
              ),
          ],
        ),
        actions: actions,
      ),
      body: Column(
        children: <Widget>[
          Expanded(child: IndexedStack(index: _index, children: _pages)),
          const _ShellFooter(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: _destinations,
      ),
    );
  }
}

class _ShellFooter extends StatelessWidget {
  const _ShellFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      color: AppColors.surface,
      child: const RiskDisclaimer(),
    );
  }
}
