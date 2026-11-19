import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/session_providers.dart';
import '../domain/portfolio_summary.dart';
import 'portfolio_providers.dart';
import 'widgets/allocation_chart.dart';
import 'widgets/holding_card.dart';
import 'widgets/summary_header_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final profile = ref.watch(activeProfileProvider);

    Future<void> refresh() async {
      ref.invalidate(transactionFeedProvider);
      ref.invalidate(portfolioSummaryProvider);
      try {
        await ref.read(portfolioSummaryProvider.future);
      } catch (_) {
        // The error state is rendered by AsyncValueView.
      }
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _Greeting(name: profile?.fullName ?? ''),
                  const SizedBox(height: 18),
                  AsyncValueView<PortfolioSummary>(
                    asyncValue: summaryAsync,
                    loading: const _DashboardLoading(),
                    onRetry: refresh,
                    builder: (summary) => _DashboardBody(summary: summary),
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

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

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
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                Formatters.date(now),
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const <Widget>[
              Icon(Icons.shield_outlined, size: 12, color: AppColors.emeraldDeep),
              SizedBox(width: 5),
              Text(
                'Verified',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SummaryHeaderCard(summary: summary),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = AllocationChartCard(holdings: summary.holdings);
            final holdings = _HoldingsSection(summary: summary);

            if (constraints.maxWidth < 940) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  chart,
                  const SizedBox(height: 16),
                  holdings,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 5, child: chart),
                const SizedBox(width: 16),
                Expanded(flex: 7, child: holdings),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          <String>[
            'Valuation ${summary.asOf == null ? '—' : 'updated ${Formatters.timestamp(summary.asOf)}'}',
            if (summary.closedSchemes > 0)
              '${summary.closedSchemes} fully redeemed scheme${summary.closedSchemes == 1 ? '' : 's'} excluded',
          ].join('  ·  '),
          style: const TextStyle(fontSize: 11, color: AppColors.slateLight),
        ),
      ],
    );
  }
}

class _HoldingsSection extends StatelessWidget {
  const _HoldingsSection({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.holdings.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            SectionHeader(
              title: 'Holdings',
              subtitle: 'Scheme-wise breakdown',
            ),
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No holdings yet',
              message:
                  'CAMS statements are collected every 6 hours. Your schemes '
                  'will appear here after the next sync.',
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: 'Holdings',
          subtitle:
              '${summary.holdings.length} active scheme${summary.holdings.length == 1 ? '' : 's'}'
              '  ·  ${Formatters.units(summary.totalUnits)} units',
        ),
        const SizedBox(height: 12),
        for (final holding in summary.holdings) ...<Widget>[
          HoldingCard(holding: holding),
          const SizedBox(height: 10),
        ],
      ],
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
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: 14),
          Text(
            'Reconciling your portfolio…',
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}
