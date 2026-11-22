import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/risk_disclaimer.dart';
import '../../auth/presentation/session_providers.dart';
import 'admin_clients_screen.dart';
import 'admin_sync_screen.dart';

/// Visible only to fundmfservices@gmail.com (enforced again by Firestore rules).
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    AdminClientsScreen(),
    AdminSyncScreen(),
  ];

  static const List<NavigationDestination> _destinations =
      <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.people_outline_rounded),
      selectedIcon: Icon(Icons.people_rounded),
      label: 'Clients',
    ),
    NavigationDestination(
      icon: Icon(Icons.sync_outlined),
      selectedIcon: Icon(Icons.sync_rounded),
      label: 'CAMS sync',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final appBar = AppBar(
      title: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Fundmf admin'),
        ],
      ),
      actions: <Widget>[
        PopupMenuButton<String>(
          tooltip: 'Admin menu',
          onSelected: (value) async {
            if (value == 'signout') {
              await ref.read(authRepositoryProvider).signOut();
            }
          },
          itemBuilder: (context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'signout',
              child: Text('Sign out'),
            ),
          ],
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: <Widget>[
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              selectedIndex: _index,
              onDestinationSelected: (index) => setState(() => _index = index),
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.emeraldWash,
              labelType: MediaQuery.sizeOf(context).width >= 1200
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: const <NavigationRailDestination>[
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: Text('Clients'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.sync_outlined),
                  selectedIcon: Icon(Icons.sync_rounded),
                  label: Text('CAMS sync'),
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
      appBar: appBar,
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
