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
import '../domain/transaction_model.dart';
import 'exporter_providers.dart';
import 'transaction_providers.dart';
import 'widgets/transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';

enum _ExportFormat { csv, pdf }

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
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: now,
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
      if (format == _ExportFormat.csv) {
        await exporter.shareCsv(transactions: transactions, profile: profile);
      } else {
        await exporter.sharePdf(transactions: transactions, profile: profile);
      }
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _search,
                    onChanged: ref.read(transactionFilterProvider.notifier).setQuery,
                    decoration: InputDecoration(
                      hintText: 'Search transaction ID or scheme',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: filter.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _search.clear();
                                ref
                                    .read(transactionFilterProvider.notifier)
                                    .setQuery('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
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
                                selected: filter.filter ==
                                    TransactionFilter.purchases,
                                onSelected: () => ref
                                    .read(transactionFilterProvider.notifier)
                                    .setFilter(TransactionFilter.purchases),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Redemptions',
                                selected: filter.filter ==
                                    TransactionFilter.redemptions,
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<_ExportFormat>(
                        enabled: !_exporting,
                        tooltip: 'Export report',
                        onSelected: (format) {
                          final all =
                              ref.read(transactionFeedProvider).value ??
                                  const <FundTransaction>[];
                          _export(filter.apply(all), format);
                        },
                        itemBuilder: (context) => const <PopupMenuEntry<_ExportFormat>>[
                          PopupMenuItem<_ExportFormat>(
                            value: _ExportFormat.csv,
                            child: Text('Share as CSV'),
                          ),
                          PopupMenuItem<_ExportFormat>(
                            value: _ExportFormat.pdf,
                            child: Text('Share as PDF'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _exporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.ios_share_rounded,
                                  size: 18,
                                  color: AppColors.navy,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
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
                          'Transactions are imported from CAMS emails every 6 '
                          'hours. They will appear here automatically.',
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
                          ref
                              .read(transactionFilterProvider.notifier)
                              .reset();
                        },
                        child: const Text('Clear filters'),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                    itemCount: filtered.length + 1,
                    separatorBuilder: (_, index) =>
                        SizedBox(height: index == 0 ? 0 : 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final inflow = filtered
                            .where((t) => t.kind.isInflow)
                            .fold<double>(0, (sum, t) => sum + t.amount);
                        final outflow = filtered
                            .where((t) => t.kind.isOutflow)
                            .fold<double>(0, (sum, t) => sum + t.amount);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: _Totals(
                                    label: '${filtered.length} shown',
                                    value: Formatters.currency(
                                      inflow - outflow,
                                    ),
                                    caption: 'net invested',
                                  ),
                                ),
                                Expanded(
                                  child: _Totals(
                                    label: 'Purchases',
                                    value: Formatters.currency(inflow),
                                    caption: 'inflow',
                                    color: AppColors.emeraldDeep,
                                  ),
                                ),
                                Expanded(
                                  child: _Totals(
                                    label: 'Redemptions',
                                    value: Formatters.currency(outflow),
                                    caption: 'outflow',
                                    color: AppColors.coralDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final transaction = filtered[index - 1];
                      return TransactionTile(
                        transaction: transaction,
                        onTap: () =>
                            TransactionDetailSheet.show(context, transaction),
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
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.navy,
      ),
      selectedColor: AppColors.navy,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: selected ? AppColors.navy : AppColors.border,
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
            color: AppColors.navy,
          ),
          label: Text(label),
          onPressed: onTap,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
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
            icon: const Icon(Icons.close_rounded, size: 16),
          ),
      ],
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
          style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.navy,
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
