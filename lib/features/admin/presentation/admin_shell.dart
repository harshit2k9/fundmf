import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/risk_disclaimer.dart';
import '../../auth/presentation/session_providers.dart';
import 'admin_clients_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_providers.dart';
import 'admin_reports_screen.dart';
import 'admin_sync_screen.dart';

/// Visible only to fundmfservices@gmail.com (enforced again by Firestore rules).
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const List<_AdminNav> _items = <_AdminNav>[
    _AdminNav(
      label: 'Overview',
      subtitle: 'Book of business and approvals',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard_rounded,
    ),
    _AdminNav(
      label: 'Clients',
      subtitle: 'Directory and provisioning',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
    ),
    _AdminNav(
      label: 'CAMS sync',
      subtitle: 'Statement pipeline and run history',
      icon: Icons.sync_outlined,
      selectedIcon: Icons.sync_rounded,
    ),
    _AdminNav(
      label: 'Reports',
      subtitle: 'Directory and client statements',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
    ),
  ];

  void _goTo(int index) => setState(() => _index = index);

  List<Widget> get _pages => <Widget>[
        AdminOverviewScreen(onNavigate: _goTo),
        const AdminClientsScreen(),
        const AdminSyncScreen(),
        const AdminReportsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final pending = ref.watch(adminPendingClientsProvider).length;

    void refresh() {
      ref.invalidate(adminClientsProvider);
      ref.invalidate(adminClientPortfoliosProvider);
      ref.invalidate(adminSyncLogsProvider);
    }

    final actions = <Widget>[
      IconButton(
        tooltip: 'Refresh directory',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded, size: 20),
      ),
      PopupMenuButton<String>(
        tooltip: 'Admin menu',
        offset: const Offset(0, 44),
        onSelected: (value) async {
          if (value == 'signout') {
            await ref.read(authRepositoryProvider).signOut();
          }
        },
        itemBuilder: (context) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
        ],
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.ink,
            child: Text(
              'A',
              style: TextStyle(
                color: AppColors.goldSoft,
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
            _AdminSidePanel(
              items: _items,
              index: _index,
              extended: width >= 1180,
              pending: pending,
              onSelect: _goTo,
              onSignOut: () => ref.read(authRepositoryProvider).signOut(),
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  _AdminTopBar(
                    title: _items[_index].label,
                    pending: pending,
                    actions: actions,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: IndexedStack(index: _index, children: _pages),
                  ),
                  const _AdminFooter(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: <Widget>[
          _AdminMobileHeader(
            pending: pending,
            onRefresh: refresh,
            onSignOut: () => ref.read(authRepositoryProvider).signOut(),
          ),
          _AdminTabStrip(
            items: _items,
            index: _index,
            pending: pending,
            onSelect: _goTo,
          ),
          Expanded(child: IndexedStack(index: _index, children: _pages)),
          const _AdminFooter(),
        ],
      ),
    );
  }
}

class _AdminNav {
  const _AdminNav({
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

class _AdminSidePanel extends StatelessWidget {
  const _AdminSidePanel({
    required this.items,
    required this.index,
    required this.extended,
    required this.pending,
    required this.onSelect,
    required this.onSignOut,
  });

  final List<_AdminNav> items;
  final int index;
  final bool extended;
  final int pending;
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  if (extended) ...<Widget>[
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'FUNDMF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'ADMIN CONSOLE',
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
                    _AdminNavButton(
                      item: items[i],
                      selected: index == i,
                      extended: extended,
                      badge: i == 1 && pending > 0 ? '$pending' : null,
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
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavButton extends StatelessWidget {
  const _AdminNavButton({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badge,
  });

  final _AdminNav item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  final String? badge;

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
                      ),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: AppColors.inkDeep,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
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

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.pending,
    required this.actions,
  });

  final String title;
  final int pending;
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
                    const Text(
                      'FUNDMF ADMIN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: AppColors.slateLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, color: AppColors.gold),
                    if (pending > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amberWash,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$pending awaiting approval',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amber,
                          ),
                        ),
                      ),
                    ],
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

class _AdminFooter extends StatelessWidget {
  const _AdminFooter();

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

/// Ink brand bar used on phones and narrow tablets.
class _AdminMobileHeader extends StatelessWidget {
  const _AdminMobileHeader({
    required this.pending,
    required this.onRefresh,
    required this.onSignOut,
  });

  final int pending;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 6, 11),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'ADMIN CONSOLE',
                      style: TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending > 0)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$pending pending',
                    style: const TextStyle(
                      color: AppColors.inkDeep,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Refresh directory',
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Admin menu',
                offset: const Offset(0, 40),
                onSelected: (value) {
                  if (value == 'signout') onSignOut();
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'signout', child: Text('Sign out')),
                ],
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.gold,
                  child: const Text(
                    'A',
                    style: TextStyle(
                      color: AppColors.inkDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal section switcher shown under the mobile brand bar.
class _AdminTabStrip extends StatelessWidget {
  const _AdminTabStrip({
    required this.items,
    required this.index,
    required this.pending,
    required this.onSelect,
  });

  final List<_AdminNav> items;
  final int index;
  final int pending;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: <Widget>[
            for (var i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 7),
              _AdminTabChip(
                item: items[i],
                selected: index == i,
                badge: i == 1 && pending > 0,
                onTap: () => onSelect(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminTabChip extends StatelessWidget {
  const _AdminTabChip({
    required this.item,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final _AdminNav item;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 15,
                color: selected ? AppColors.goldSoft : AppColors.slate,
              ),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              if (badge) ...<Widget>[
                const SizedBox(width: 5),
                Container(
                  width: 6,
                  height: 6,
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
    );
  }
}
