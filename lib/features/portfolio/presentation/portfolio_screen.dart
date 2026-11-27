import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/document_delivery.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/presentation/session_providers.dart';
import '../../reports/presentation/report_providers.dart';
import '../domain/portfolio_analytics.dart';
import '../domain/portfolio_summary.dart';
import '../domain/scheme_holding.dart';
import 'portfolio_providers.dart';
import 'widgets/allocation_chart.dart';
import 'widgets/holding_card.dart';
import 'widgets/scheme_detail_sheet.dart';

enum _HoldingsSort { value, pnl, name }

/// The investor's holdings workspace: every scheme, sortable, with allocation
/// detail, ledger analytics and a one-tap portfolio statement.
class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  _HoldingsSort _sort = _HoldingsSort.value;
  bool _exporting = false;

  List<SchemeHolding> _sorted(List<SchemeHolding> holdings) {
    final list = List<SchemeHolding>.of(holdings);
    switch (_sort) {
      case _HoldingsSort.value:
        list.sort((a, b) => b.currentValue.compareTo(a.currentValue));
      case _HoldingsSort.pnl:
        list.sort((a, b) => b.pnlPercent.compareTo(a.pnlPercent));
      case _HoldingsSort.name:
        list.sort((a, b) => a.schemeName.compareTo(b.schemeName));
    }
    return list;
  }

  Future<void> _downloadStatement(PortfolioSummary summary) async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null || _exporting) return;

    setState(() => _exporting = true);
    try {
      final result = await ref.read(reportExporterProvider).exportPortfolioStatementPdf(
            summary: summary,
            profile: profile,
          );
      if (!mounted) return;
      _notify(result, 'Portfolio statement');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate the statement: '
              '${AppException.describe(error)}'),
          backgroundColor: AppColors.coralDeep,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _notify(DeliveryResult result, String label) {
    final message = result.delivered
        ? '$label is ready. Choose where to save it.'
        : (result.message ?? '$label was saved to the app storage.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final analytics = ref.watch(portfolioAnalyticsProvider).value;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(transactionFeedProvider);
        ref.invalidate(portfolioSummaryProvider);
        ref.invalidate(portfolioAnalyticsProvider);
      },
      color: AppColors.ink,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: AsyncValueView<PortfolioSummary>(
                asyncValue: summaryAsync,
                onRetry: () => ref.invalidate(portfolioSummaryProvider),
                builder: (summary) {
                  final holdings = _sorted(summary.holdings);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _PortfolioHeader(
                        summary: summary,
                        exporting: _exporting,
                        onExport: () => _downloadStatement(summary),
                      ),
                      const SizedBox(height: 14),
                      _PositionSummary(summary: summary),
                      const SizedBox(height: 18),
                      SectionHeader(
                        eyebrow: 'Holdings',
                        title: '${holdings.length} active scheme'
                            '${holdings.length == 1 ? '' : 's'}',
                        subtitle:
                            '${Formatters.units(summary.totalUnits)} units across '
                            '${holdings.expand((h) => h.folios).where((f) => f.trim().isNotEmpty).toSet().length} folios',
                        trailing: PopupMenuButton<_HoldingsSort>(
                          tooltip: 'Sort holdings',
                          initialValue: _sort,
                          onSelected: (value) => setState(() => _sort = value),
                          itemBuilder: (context) =>
                              const <PopupMenuEntry<_HoldingsSort>>[
                            PopupMenuItem<_HoldingsSort>(
                              value: _HoldingsSort.value,
                              child: Text('By current value'),
                            ),
                            PopupMenuItem<_HoldingsSort>(
                              value: _HoldingsSort.pnl,
                              child: Text('By return %'),
                            ),
                            PopupMenuItem<_HoldingsSort>(
                              value: _HoldingsSort.name,
                              child: Text('By scheme name'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.swap_vert_rounded, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  'Sort',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (holdings.isEmpty)
                        const AppCard(
                          child: EmptyState(
                            icon: Icons.pie_chart_outline_rounded,
                            title: 'No holdings yet',
                            message:
                                'Your schemes appear here once your CAMS '
                                'statements are imported.',
                          ),
                        )
                      else ...<Widget>[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 900) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  for (final holding in holdings) ...<Widget>[
                                    HoldingCard(
                                      holding: holding,
                                      onTap: () => SchemeDetailSheet.show(
                                        context,
                                        holding,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                              );
                            }
                            return _HoldingsGrid(holdings: holdings);
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final analyticsCard =
                              _InvestmentHistory(analytics: analytics);
                          final allocation =
                              AllocationChartCard(holdings: holdings);
                          if (constraints.maxWidth < 900) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                analyticsCard,
                                const SizedBox(height: 16),
                                allocation,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(flex: 7, child: analyticsCard),
                              const SizedBox(width: 16),
                              Expanded(flex: 5, child: allocation),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingsGrid extends StatelessWidget {
  const _HoldingsGrid({required this.holdings});

  final List<SchemeHolding> holdings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final holding in holdings)
              SizedBox(
                width: width,
                child: HoldingCard(
                  holding: holding,
                  onTap: () => SchemeDetailSheet.show(context, holding),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PortfolioHeader extends StatelessWidget {
  const _PortfolioHeader({
    required this.summary,
    required this.exporting,
    required this.onExport,
  });

  final PortfolioSummary summary;
  final bool exporting;
  final VoidCallback onExport;

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
                'Your holdings',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary.isEmpty
                    ? 'Nothing to value yet'
                    : 'Valued ${summary.hasLiveNav ? 'at live AMFI NAVs' : 'at average cost'}'
                        '${summary.asOf == null ? '' : '  ·  ${Formatters.timestamp(summary.asOf)}'}',
                style: const TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: summary.isEmpty || exporting ? null : onExport,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          icon: exporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 17),
          label: Text(exporting ? 'Preparing…' : 'Statement'),
        ),
      ],
    );
  }
}

class _PositionSummary extends StatelessWidget {
  const _PositionSummary({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tiles = <Widget>[
          StatTile(
            label: 'Invested',
            value: Formatters.currency(summary.totalInvested),
            caption: 'At average cost',
          ),
          StatTile(
            label: 'Current value',
            value: Formatters.currency(summary.currentValue),
            caption: summary.hasLiveNav ? 'Live AMFI NAV' : 'Average cost NAV',
          ),
          StatTile(
            label: 'Absolute gain',
            value: Formatters.signedCurrency(summary.absolutePnl),
            caption: Formatters.signedPercent(summary.returnPercent),
            accent: AppColors.forChange(summary.absolutePnl),
            wash: AppColors.washForChange(summary.absolutePnl),
          ),
          StatTile(
            label: 'CAGR',
            value: Formatters.signedPercent(summary.cagrPercent),
            caption: 'Annualised since first investment',
            accent: AppColors.goldDeep,
            wash: AppColors.goldWash,
          ),
        ];
        final columns = constraints.maxWidth >= 860 ? 4 : 2;
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

class _InvestmentHistory extends StatelessWidget {
  const _InvestmentHistory({required this.analytics});

  final PortfolioAnalytics? analytics;

  @override
  Widget build(BuildContext context) {
    final data = analytics;
    if (data == null || data.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.timeline_rounded,
          title: 'No investment history yet',
          message:
              'Year-wise totals appear once your statements have been parsed.',
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            eyebrow: 'History',
            title: 'Investments by year',
            subtitle: 'Money in and out, straight from CAMS',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < data.yearly.length; index++) ...<Widget>[
            if (index > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${data.yearly[index].year}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${Formatters.currency(data.yearly[index].invested)} in'
                      '${data.yearly[index].redeemed > 0 ? '  ·  ${Formatters.currency(data.yearly[index].redeemed)} out' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.signedCurrency(data.yearly[index].net),
                    style: const TextStyle(
                      fontSize: 11.5,
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
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: <Widget>[
              _HistoryStat(
                label: 'First investment',
                value: Formatters.date(data.firstInvestmentDate),
              ),
              _HistoryStat(
                label: 'SIP instalments',
                value: '${data.sipCount}',
              ),
              _HistoryStat(
                label: 'Avg. monthly',
                value: Formatters.currency(data.averageMonthlyInvestment),
              ),
              _HistoryStat(
                label: 'Transactions',
                value: '${data.transactionCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
