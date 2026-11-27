import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/session_providers.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../reports/presentation/report_providers.dart';
import '../domain/transaction_model.dart';
import 'transaction_providers.dart';
import 'widgets/transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';

enum _ExportFormat { csv, pdf }

/// The CAMS ledger: searchable, filterable by type and period, grouped by
/// month, with one-tap CSV/PDF export.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final current = ref.read(transactionFilterProvider).range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: current,
      helpText: 'Filter transactions by date',
    );
    if (picked == null || !mounted) return;
    ref.read(transactionFilterProvider.notifier).setRange(picked);
  }

  Future<void> _export(
    List<FundTransaction> transactions,
    _ExportFormat format,
  ) async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;

    setState(() => _exporting = true);
    try {
      final exporter = ref.read(reportExporterProvider);
      final result = format == _ExportFormat.csv
          ? await exporter.exportTransactionLedgerCsv(
              transactions: transactions,
              profile: profile,
            )
          : await exporter.exportTransactionLedgerPdf(
              transactions: transactions,
              profile: profile,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.delivered
                ? 'Ledger is ready — choose where to save it.'
                : (result.message ?? 'Ledger saved to app storage.'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${AppException.describe(error)}'),
          backgroundColor: AppColors.coralDeep,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(transactionFeedProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged:
                              ref.read(transactionFilterProvider.notifier).setQuery,
                          decoration: InputDecoration(
                            hintText: 'Search transaction ID or scheme',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 19),
                            suffixIcon: filter.query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close_rounded,
                                        size: 17),
                                    onPressed: () {
                                      _search.clear();
                                      ref
                                          .read(transactionFilterProvider.notifier)
                                          .setQuery('');
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      PopupMenuButton<_ExportFormat>(
                        enabled: !_exporting,
                        tooltip: 'Export ledger',
                        onSelected: (format) {
                          final all = ref
                                  .read(transactionFeedProvider)
                                  .value ??
                              const <FundTransaction>[];
                          _export(filter.apply(all), format);
                        },
                        itemBuilder: (context) =>
                            const <PopupMenuEntry<_ExportFormat>>[
                          PopupMenuItem<_ExportFormat>(
                            value: _ExportFormat.csv,
                            child: Text('Export as CSV'),
                          ),
                          PopupMenuItem<_ExportFormat>(
                            value: _ExportFormat.pdf,
                            child: Text('Export as PDF'),
                          ),
                        ],
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (_exporting)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.download_rounded,
                                  size: 17,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                'Export',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _FilterChip(
                          label: 'All',
                          selected: filter.filter == TransactionFilter.all,
                          onSelected: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setFilter(TransactionFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Purchases & SIP',
                          selected:
                              filter.filter == TransactionFilter.purchases,
                          onSelected: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setFilter(TransactionFilter.purchases),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Redemptions',
                          selected:
                              filter.filter == TransactionFilter.redemptions,
                          onSelected: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setFilter(TransactionFilter.redemptions),
                        ),
                        const SizedBox(width: 8),
                        _DateRangeChip(
                          range: filter.range,
                          onTap: _pickDateRange,
                          onClear: () => ref
                              .read(transactionFilterProvider.notifier)
                              .setRange(null),
                        ),
                        if (filter.isActive) ...<Widget>[
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () {
                              _search.clear();
                              ref
                                  .read(transactionFilterProvider.notifier)
                                  .reset();
                            },
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Reset'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: AsyncValueView<List<FundTransaction>>(
                asyncValue: feed,
                onRetry: () => ref.invalidate(transactionFeedProvider),
                builder: (transactions) {
                  final filtered = filter.apply(transactions);
                  if (transactions.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No transactions yet',
                      message:
                          'Transactions are imported from CAMS statements '
                          'every day at 9 AM.',
                    );
                  }
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching transactions',
                      message:
                          'Try a different search term or clear the filters.',
                      action: OutlinedButton(
                        onPressed: () {
                          _search.clear();
                          ref.read(transactionFilterProvider.notifier).reset();
                        },
                        child: const Text('Clear filters'),
                      ),
                    );
                  }

                  final items = _buildItems(filtered);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LedgerTotals(transactions: filtered),
                        );
                      }
                      final item = items[index - 1];
                      if (item is String) {
                        return _MonthHeader(label: item);
                      }
                      final transaction = item as FundTransaction;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TransactionTile(
                          transaction: transaction,
                          onTap: () => TransactionDetailSheet.show(
                            context,
                            transaction,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Flattens the ledger into month headers followed by their rows.
  List<Object> _buildItems(List<FundTransaction> transactions) {
    final items = <Object>[];
    int? year;
    int? month;
    for (final transaction in transactions) {
      final date = transaction.transactionDate;
      if (date.year != year || date.month != month) {
        year = date.year;
        month = date.month;
        items.add(Formatters.monthYear(date));
      }
      items.add(transaction);
    }
    return items;
  }
}

class _LedgerTotals extends StatelessWidget {
  const _LedgerTotals({required this.transactions});

  final List<FundTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final inflow = transactions
        .where((transaction) => transaction.kind.isInflow)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final outflow = transactions
        .where((transaction) => transaction.kind.isOutflow)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Totals(
              label: 'ENTRIES',
              value: '${transactions.length}',
              caption: 'in this view',
            ),
          ),
          Expanded(
            child: _Totals(
              label: 'PURCHASES',
              value: Formatters.currency(inflow),
              caption: 'money in',
              color: AppColors.emeraldDeep,
            ),
          ),
          Expanded(
            child: _Totals(
              label: 'REDEMPTIONS',
              value: Formatters.currency(outflow),
              caption: 'money out',
              color: AppColors.coralDeep,
            ),
          ),
          Expanded(
            child: _Totals(
              label: 'NET',
              value: Formatters.currency(inflow - outflow),
              caption: 'invested',
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.label,
    required this.value,
    required this.caption,
    this.color,
  });

  final String label;
  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.slateLight,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.ink,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          caption,
          style: const TextStyle(fontSize: 9.5, color: AppColors.slateLight),
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.slate,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.ink,
      ),
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.ink : AppColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({
    required this.range,
    required this.onTap,
    required this.onClear,
  });

  final DateTimeRange? range;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final label = range == null
        ? 'Date range'
        : '${Formatters.shortDate(range!.start)} – ${Formatters.shortDate(range!.end)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ActionChip(
          avatar: const Icon(
            Icons.calendar_month_outlined,
            size: 15,
            color: AppColors.ink,
          ),
          label: Text(label),
          onPressed: onTap,
          labelStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        if (range != null)
          IconButton(
            tooltip: 'Clear date range',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 15),
          ),
      ],
    );
  }
}
