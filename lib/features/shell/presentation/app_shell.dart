import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/risk_disclaimer.dart';
import '../../auth/presentation/session_providers.dart';
import '../../portfolio/presentation/dashboard_screen.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../portfolio/presentation/portfolio_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';

/// Investor shell: an ink navigation panel on tablet/desktop, a bottom bar on
/// phones, with a quiet top bar that carries the page title and account menu.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      label: 'Overview',
      subtitle: 'Portfolio summary and activity',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    _NavItem(
      label: 'Portfolio',
      subtitle: 'Holdings, allocation and history',
      icon: Icons.pie_chart_outline_rounded,
      selectedIcon: Icons.pie_chart_rounded,
    ),
    _NavItem(
      label: 'Activity',
      subtitle: 'CAMS transaction ledger',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _NavItem(
      label: 'Reports',
      subtitle: 'Statements and exports',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
    ),
    _NavItem(
      label: 'Profile',
      subtitle: 'Account and security',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  void _goTo(int index) => setState(() => _index = index);

  void _refresh() {
    ref.invalidate(transactionFeedProvider);
    ref.invalidate(portfolioSummaryProvider);
    ref.invalidate(portfolioAnalyticsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refreshing portfolio and ledger…')),
    );
  }

  Future<void> _signOut() => ref.read(authRepositoryProvider).signOut();

  List<Widget> get _pages => <Widget>[
        DashboardScreen(onNavigate: _goTo),
        const PortfolioScreen(),
        const TransactionsScreen(),
        const ReportsScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final profile = ref.watch(activeProfileProvider);
    final item = _items[_index];

    final actions = <Widget>[
      IconButton(
        tooltip: 'Refresh portfolio',
        onPressed: _refresh,
        icon: const Icon(Icons.refresh_rounded, size: 20),
      ),
      PopupMenuButton<String>(
        tooltip: 'Account',
        offset: const Offset(0, 44),
        onSelected: (value) {
          if (value == 'refresh') _refresh();
          if (value == 'profile') _goTo(4);
          if (value == 'signout') _signOut();
        },
        itemBuilder: (context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'refresh', child: Text('Refresh data')),
          PopupMenuItem<String>(value: 'profile', child: Text('My profile')),
          PopupMenuDivider(),
          PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.ink,
            child: Text(
              profile?.initials ?? 'F',
              style: const TextStyle(
                color: AppColors.goldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            _SidePanel(
              items: _items,
              index: _index,
              extended: width >= 1180,
              userName: profile?.fullName ?? '',
              clientId: profile?.clientId ?? '',
              onSelect: _goTo,
              onSignOut: _signOut,
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _TopBar(
                    title: item.label,
                    subtitle: item.subtitle,
                    actions: actions,
                  ),
                  const Divider(height: 1),
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
        titleSpacing: 16,
        title: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'F',
                style: TextStyle(
                  color: AppColors.goldSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
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
        onDestinationSelected: _goTo,
        destinations: <NavigationDestination>[
          for (final navItem in _items)
            NavigationDestination(
              icon: Icon(navItem.icon),
              selectedIcon: Icon(navItem.selectedIcon),
              label: navItem.label,
              tooltip: navItem.label,
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.items,
    required this.index,
    required this.extended,
    required this.userName,
    required this.clientId,
    required this.onSelect,
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int index;
  final bool extended;
  final String userName;
  final String clientId;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 244 : 80,
      color: AppColors.inkDeep,
      child: SafeArea(
        right: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                extended ? 18 : 0,
                20,
                extended ? 18 : 0,
                22,
              ),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      'F',
                      style: TextStyle(
                        color: AppColors.inkDeep,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (extended) ...<Widget>[
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'WEALTH MANAGEMENT',
                          style: TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: 7,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: extended ? 10 : 8),
                children: <Widget>[
                  for (var i = 0; i < items.length; i++)
                    _SideNavButton(
                      item: items[i],
                      selected: index == i,
                      extended: extended,
                      onTap: () => onSelect(i),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 8),
              child: Column(
                children: <Widget>[
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: extended
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        child: Text(
                          Formatters.initials(userName),
                          style: const TextStyle(
                            color: AppColors.goldSoft,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (extended) ...<Widget>[
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                Formatters.firstName(userName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                clientId.isEmpty ? 'Investor' : clientId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 9.5,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (extended)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onSignOut,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.7),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 15),
                        label: const Text('Sign out'),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: onSignOut,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 17,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNavButton extends StatelessWidget {
  const _SideNavButton({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.07) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: extended ? 10 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: selected ? AppColors.gold : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.55),
                ),
                if (extended) ...<Widget>[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.62),
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(22, 10, 10, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: AppColors.slateLight.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, color: AppColors.gold),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 9),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: const RiskDisclaimer(),
    );
  }
}
