import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/transaction_model.dart';

enum TransactionFilter { all, purchases, redemptions }

/// Search, chip filter and date range for the transactions report.
class TransactionFilterState {
  const TransactionFilterState({
    this.filter = TransactionFilter.all,
    this.query = '',
    this.range,
  });

  final TransactionFilter filter;
  final String query;
  final DateTimeRange? range;

  bool get isActive =>
      filter != TransactionFilter.all ||
      query.trim().isNotEmpty ||
      range != null;

  /// Applies search (transaction id or scheme name), type chip and date range.
  List<FundTransaction> apply(List<FundTransaction> source) {
    final needle = query.trim().toLowerCase();
    return source.where((transaction) {
      if (needle.isNotEmpty) {
        final matchesId =
            transaction.transactionId.toLowerCase().contains(needle);
        final matchesScheme =
            transaction.schemeName.toLowerCase().contains(needle);
        if (!matchesId && !matchesScheme) return false;
      }

      if (filter == TransactionFilter.purchases &&
          !transaction.kind.isInflow) {
        return false;
      }
      if (filter == TransactionFilter.redemptions &&
          !transaction.kind.isOutflow) {
        return false;
      }

      final range = this.range;
      if (range != null) {
        final date = DateUtils.dateOnly(transaction.transactionDate);
        if (date.isBefore(DateUtils.dateOnly(range.start)) ||
            date.isAfter(DateUtils.dateOnly(range.end))) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);
  }

  TransactionFilterState copyWith({
    TransactionFilter? filter,
    String? query,
    DateTimeRange? range,
    bool clearRange = false,
  }) {
    return TransactionFilterState(
      filter: filter ?? this.filter,
      query: query ?? this.query,
      range: clearRange ? null : (range ?? this.range),
    );
  }
}

class TransactionFilterController extends Notifier<TransactionFilterState> {
  @override
  TransactionFilterState build() => const TransactionFilterState();

  void setFilter(TransactionFilter filter) =>
      state = state.copyWith(filter: filter);

  void setQuery(String query) => state = state.copyWith(query: query);

  void setRange(DateTimeRange? range) => state = range == null
      ? state.copyWith(clearRange: true)
      : state.copyWith(range: range);

  void reset() => state = const TransactionFilterState();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterController, TransactionFilterState>(
  TransactionFilterController.new,
);
