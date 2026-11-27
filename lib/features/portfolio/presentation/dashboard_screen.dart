import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../domain/portfolio_analytics.dart';
import '../domain/portfolio_summary.dart';
import '../domain/scheme_holding.dart';
import 'portfolio_providers.dart';
import 'widgets/allocation_chart.dart';
import 'widgets/holding_card.dart';
import 'widgets/investment_flow_chart.dart';
import 'widgets/summary_header_card.dart';

/// Investor overview: valuation, activity, composition and recent ledger
/// entries in one comfortable dashboard.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// Moves the shell to another section (1 = Portfolio, 2 = Activity).
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final profile = ref.watch(activeProfileProvider);
    final analytics = ref.watch(portfolioAnalyticsProvider).value;

    Future<void> refresh() async {
      ref.invalidate(transactionFeedProvider);
      ref.invalidate(portfolioSummaryProvider);
      ref.invalidate(portfolioAnalyticsProvider);
      try {
        await ref.read(portfolioSummaryProvider.future);
      } catch (_) {
        // The error state is rendered by AsyncValueView.
      }
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
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _OverviewHeader(
                    name: profile?.fullName ?? '',
                    clientId: profile?.clientId ?? '',
                  ),
                  const SizedBox(height: 16),
                  AsyncValueView<PortfolioSummary>(
                    asyncValue: summaryAsync,
                    loading: const _DashboardLoading(),
                    onRetry: refresh,
                    builder: (summary) => _OverviewBody(
                      summary: summary,
                      analytics: analytics,
                      onNavigate: onNavigate,
                    ),
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

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.name, required this.clientId});

  final String name;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${Formatters.greeting(now)}, ${Formatters.firstName(name)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Formatters.date(now)}'
                '${clientId.isEmpty ? '' : '   ·   Client $clientId'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.slate,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.verified_user_outlined,
                size: 12,
                color: AppColors.emeraldDeep,
              ),
              SizedBox(width: 5),
              Text(
                'VERIFIED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.emeraldDeep,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({
    required this.summary,
    required this.analytics,
    this.onNavigate,
  });

  final PortfolioSummary summary;
  final PortfolioAnalytics? analytics;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions =
        ref.watch(transactionFeedProvider).value ?? const <FundTransaction>[];
    final recent = transactions.take(5).toList(growable: false);

    final folios = summary.holdings
        .expand((holding) => holding.folios)
        .where((folio) => folio.trim().isNotEmpty)
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SummaryHeaderCard(summary: summary),
        const SizedBox(height: 12),
        _StatGrid(
          tiles: <Widget>[
            StatTile(
              label: 'Invested',
              value: Formatters.currency(summary.totalInvested),
              caption: '${summary.holdings.length} active schemes',
              icon: Icons.savings_outlined,
            ),
            StatTile(
              label: 'Unrealised P&L',
              value: Formatters.signedCurrency(summary.absolutePnl),
              caption: Formatters.signedPercent(summary.returnPercent),
              icon: summary.isProfit
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              accent: AppColors.forChange(summary.absolutePnl),
              wash: AppColors.washForChange(summary.absolutePnl),
            ),
            StatTile(
              label: 'Units held',
              value: Formatters.units(summary.totalUnits),
              caption: '$folios folio${folios == 1 ? '' : 's'}',
              icon: Icons.layers_outlined,
            ),
            StatTile(
              label: 'Valuation',
              value: summary.hasLiveNav ? 'Live NAV' : 'Average cost',
              caption: summary.asOf == null
                  ? 'Not valued yet'
                  : Formatters.timestamp(summary.asOf),
              icon: Icons.bolt_outlined,
              wash: AppColors.goldWash,
              accent: AppColors.goldDeep,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 940;
            final performance = _PerformancePanel(
              analytics: analytics,
              summary: summary,
              onOpenPortfolio: onNavigate == null
                  ? null
                  : () => onNavigate!(1),
            );
            final allocation = AllocationChartCard(holdings: summary.holdings);

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  performance,
                  const SizedBox(height: 16),
                  allocation,
                  const SizedBox(height: 16),
                  _TopHoldings(
                    summary: summary,
                    onViewAll:
                        onNavigate == null ? null : () => onNavigate!(1),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 7, child: performance),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: allocation),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 7,
                      child: _TopHoldings(
                        summary: summary,
                        onViewAll:
                            onNavigate == null ? null : () => onNavigate!(1),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _RecentActivity(
                        transactions: recent,
                        onViewAll:
                            onNavigate == null ? null : () => onNavigate!(2),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        if (transactions.isEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _RecentActivity(transactions: recent, onViewAll: null),
        ],
        const SizedBox(height: 14),
        Text(
          <String>[
            'Valuation ${summary.asOf == null ? 'pending' : 'updated ${Formatters.timestamp(summary.asOf)}'}',
            if (summary.closedSchemes > 0)
              '${summary.closedSchemes} fully redeemed scheme${summary.closedSchemes == 1 ? '' : 's'} excluded',
            'Source: CAMS / KFintech statements · AMFI NAVs',
          ].join('   ·   '),
          style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.slateLight,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 4
            : (constraints.maxWidth >= 520 ? 2 : 2);
        const gap = 10.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
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

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    required this.analytics,
    required this.summary,
    this.onOpenPortfolio,
  });

  final PortfolioAnalytics? analytics;
  final PortfolioSummary summary;
  final VoidCallback? onOpenPortfolio;

  @override
  Widget build(BuildContext context) {
    final data = analytics;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            eyebrow: 'Performance',
            title: 'Investment momentum',
            subtitle: data == null
                ? 'Calculating your activity…'
                : '${data.transactionCount} transactions  ·  '
                    '${data.activeMonths} active month${data.activeMonths == 1 ? '' : 's'}',
            trailing: onOpenPortfolio == null
                ? null
                : TextButton(
                    onPressed: onOpenPortfolio,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Analytics'),
                  ),
          ),
          const SizedBox(height: 14),
          if (data == null)
            const SizedBox(
              height: 168,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...<Widget>[
            InvestmentFlowChart(flows: data.monthly),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Performer(
                    label: 'Best performer',
                    holding: data.bestHolding,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Performer(
                    label: 'Needs attention',
                    holding: data.weakestHolding,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Performer extends StatelessWidget {
  const _Performer({required this.label, required this.holding});

  final String label;
  final SchemeHolding? holding;

  @override
  Widget build(BuildContext context) {
    final holding = this.holding;
    if (holding == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.slateLight,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Not enough activity yet',
            style: TextStyle(fontSize: 11, color: AppColors.slate),
          ),
        ],
      );
    }

    final percent = holding.pnlPercent;
    final color = AppColors.forChange(percent);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.slateLight,
                  ),
                ),
              ),
              Text(
                Formatters.signedPercent(percent),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            holding.schemeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${Formatters.signedCurrency(holding.pnl)}  ·  '
            '${Formatters.currency(holding.currentValue)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _TopHoldings extends StatelessWidget {
  const _TopHoldings({required this.summary, this.onViewAll});

  final PortfolioSummary summary;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final holdings = summary.holdings.take(3).toList(growable: false);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            eyebrow: 'Holdings',
            title: 'Largest positions',
            subtitle: holdings.isEmpty
                ? 'Awaiting your first CAMS sync'
                : 'By current value',
            trailing: onViewAll == null || holdings.isEmpty
                ? null
                : TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('View all'),
                  ),
          ),
          const SizedBox(height: 12),
          if (holdings.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No holdings yet',
              message:
                  'CAMS statements are collected daily at 9 AM. Your schemes '
                  'appear here after the next sync.',
            )
          else
            for (var index = 0; index < holdings.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 10),
              HoldingCard(holding: holdings[index]),
            ],
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.transactions, this.onViewAll});

  final List<FundTransaction> transactions;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            eyebrow: 'Activity',
            title: 'Recent transactions',
            subtitle: 'Newest CAMS entries',
            trailing: onViewAll == null || transactions.isEmpty
                ? null
                : TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Ledger'),
                  ),
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              title: 'No activity yet',
              message: 'Your CAMS transactions will appear after the next sync.',
            )
          else
            for (var index = 0; index < transactions.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 8),
              TransactionTile(transaction: transactions[index]),
            ],
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: <Widget>[
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(height: 14),
          const Text(
            'Reconciling your portfolio…',
            style: TextStyle(fontSize: 12, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}
