import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../users/domain/user_profile.dart';
import '../domain/client_portfolio.dart';
import '../domain/sync_result.dart';
import 'admin_client_form_screen.dart';
import 'admin_providers.dart';

/// Admin book of business: assets under management, the approval queue and
/// recent sync health at a glance.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key, this.onNavigate});

  /// 1 = Clients, 2 = CAMS sync, 3 = Reports.
  final ValueChanged<int>? onNavigate;

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    UserProfile client,
    bool approved,
  ) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .setApproval(client.email, approved);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '${client.fullName} approved — access is now active.'
                : '${client.fullName} moved back to pending.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppException.describe(error))),
      );
    }
  }

  void _newClient(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminClientFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(adminClientPortfoliosProvider);
    final logs = ref.watch(adminSyncLogsProvider).value ?? const <SyncLogEntry>[];
    final pending = ref.watch(adminPendingClientsProvider);

    Future<void> refresh() async {
      ref.invalidate(adminClientsProvider);
      ref.invalidate(adminClientPortfoliosProvider);
      ref.invalidate(adminSyncLogsProvider);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      color: AppColors.ink,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AdminHeader(
                    onNewClient: () => _newClient(context),
                    onSync: () => onNavigate?.call(2),
                  ),
                  const SizedBox(height: 16),
                  AsyncValueView<List<AdminClientPortfolio>>(
                    asyncValue: rowsAsync,
                    onRetry: refresh,
                    builder: (rows) {
                      final totals = AdminTotals.from(rows);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _KpiGrid(totals: totals),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final queue = _ApprovalQueue(
                                clients: pending,
                                onApprove: (client) =>
                                    _approve(context, ref, client, true),
                                onReject: (client) =>
                                    _approve(context, ref, client, false),
                                onViewAll: () => onNavigate?.call(1),
                              );
                              final topClients = _TopClients(
                                rows: rows,
                                onViewAll: () => onNavigate?.call(1),
                              );

                              if (constraints.maxWidth < 940) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    queue,
                                    const SizedBox(height: 16),
                                    topClients,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(flex: 6, child: queue),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 5, child: topClients),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _SyncHealth(
                            lastRun: logs.isEmpty ? null : logs.first,
                            onOpenSync: () => onNavigate?.call(2),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onNewClient, required this.onSync});

  final VoidCallback onNewClient;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Book of business',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.date(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onSync,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.sync_rounded, size: 16),
          label: const Text('Sync'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onNewClient,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
          label: const Text('New client'),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.totals});

  final AdminTotals totals;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      StatTile(
        label: 'Assets managed',
        value: Formatters.currency(totals.aum),
        caption: '${totals.fundedClients} funded client'
            '${totals.fundedClients == 1 ? '' : 's'}',
        icon: Icons.account_balance_outlined,
        accent: AppColors.goldDeep,
        wash: AppColors.goldWash,
      ),
      StatTile(
        label: 'Total invested',
        value: Formatters.currency(totals.invested),
        caption: '${totals.schemes} scheme positions',
        icon: Icons.savings_outlined,
      ),
      StatTile(
        label: 'Unrealised P&L',
        value: Formatters.signedCurrency(totals.pnl),
        caption: Formatters.signedPercent(totals.returnPercent),
        icon: totals.pnl >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        accent: AppColors.forChange(totals.pnl),
        wash: AppColors.washForChange(totals.pnl),
      ),
      StatTile(
        label: 'Clients',
        value: '${totals.clients}',
        caption:
            '${totals.active} active  ·  ${totals.pending} pending  ·  ${totals.unclaimed} unclaimed',
        icon: Icons.people_outline_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : (constraints.maxWidth >= 560 ? 2 : 1);
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _ApprovalQueue extends StatelessWidget {
  const _ApprovalQueue({
    required this.clients,
    required this.onApprove,
    required this.onReject,
    required this.onViewAll,
  });

  final List<UserProfile> clients;
  final ValueChanged<UserProfile> onApprove;
  final ValueChanged<UserProfile> onReject;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            eyebrow: 'Access',
            title: 'Approval queue',
            subtitle: clients.isEmpty
                ? 'Nothing waiting — every linked client is approved'
                : '${clients.length} client${clients.length == 1 ? '' : 's'} waiting for access',
            trailing: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Directory'),
            ),
          ),
          const SizedBox(height: 12),
          if (clients.isEmpty)
            const EmptyState(
              icon: Icons.verified_outlined,
              title: 'All clear',
              message:
                  'New sign-ups appear here for approval before they can see '
                  'a portfolio.',
            )
          else
            for (var index = 0; index < clients.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 18),
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.goldWash,
                    child: Text(
                      clients[index].initials,
                      style: const TextStyle(
                        color: AppColors.goldDeep,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          clients[index].fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          clients[index].email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => onReject(clients[index]),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 34),
                      foregroundColor: AppColors.slate,
                    ),
                    child: const Text('Hold'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => onApprove(clients[index]),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: AppColors.emeraldDeep,
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _TopClients extends StatelessWidget {
  const _TopClients({required this.rows, required this.onViewAll});

  final List<AdminClientPortfolio> rows;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final funded = rows.where((row) => row.hasPortfolio).toList()
      ..sort(
        (a, b) => b.summary.currentValue.compareTo(a.summary.currentValue),
      );
    final top = funded.take(5).toList(growable: false);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            eyebrow: 'Clients',
            title: 'Largest portfolios',
            subtitle: 'By current value',
            trailing: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: 10),
          if (top.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No valuations yet',
              message:
                  'Portfolios appear once CAMS transactions have been imported '
                  'for your clients.',
            )
          else
            for (var index = 0; index < top.length; index++) ...<Widget>[
              if (index > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 16,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slateLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            top[index].client.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${top[index].summary.holdings.length} schemes  ·  '
                            '${Formatters.signedPercent(top[index].summary.returnPercent)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.currency(top[index].summary.currentValue),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _SyncHealth extends StatelessWidget {
  const _SyncHealth({required this.lastRun, required this.onOpenSync});

  final SyncLogEntry? lastRun;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context) {
    final run = lastRun;
    final ok = run?.isSuccess ?? false;
    return AppCard(
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: run == null
                  ? AppColors.surfaceMuted
                  : (ok ? AppColors.emeraldWash : AppColors.coralWash),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              run == null
                  ? Icons.schedule_rounded
                  : (ok ? Icons.check_rounded : Icons.error_outline_rounded),
              size: 18,
              color: run == null
                  ? AppColors.slate
                  : (ok ? AppColors.emeraldDeep : AppColors.coralDeep),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'CAMS & KFintech sync',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  run == null
                      ? 'No sync has run yet — the scheduled job runs daily at 9 AM IST.'
                      : 'Last run ${Formatters.timestamp(run.startedAt)}  ·  '
                          '${run.transactionsCreated} new  ·  '
                          '${run.duplicatesSkipped} duplicates'
                          '${run.trigger.isEmpty ? '' : '  ·  ${run.trigger}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (run != null) ...<Widget>[
            const SizedBox(width: 8),
            StatusBadge(
              label: run.status.isEmpty ? 'unknown' : run.status.toUpperCase(),
              color: ok ? AppColors.emeraldDeep : AppColors.coralDeep,
              wash: ok ? AppColors.emeraldWash : AppColors.coralWash,
              dense: true,
            ),
          ],
          const SizedBox(width: 6),
          TextButton(
            onPressed: onOpenSync,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}
