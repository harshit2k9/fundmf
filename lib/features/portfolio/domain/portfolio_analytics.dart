import '../../transactions/domain/transaction_model.dart';
import 'portfolio_summary.dart';
import 'scheme_holding.dart';

/// Investment activity for one calendar month.
class MonthlyFlow {
  const MonthlyFlow({
    required this.month,
    required this.invested,
    required this.redeemed,
    required this.transactions,
  });

  final DateTime month;
  final double invested;
  final double redeemed;
  final int transactions;

  double get net => invested - redeemed;
}

/// Investment activity for one calendar year.
class YearFlow {
  const YearFlow({
    required this.year,
    required this.invested,
    required this.redeemed,
    required this.transactions,
  });

  final int year;
  final double invested;
  final double redeemed;
  final int transactions;

  double get net => invested - redeemed;
}

/// Read-only aggregates derived from the CAMS ledger.
///
/// Everything here is computed locally from transactions the investor can
/// already read — no extra backend work and no invented figures.
class PortfolioAnalytics {
  const PortfolioAnalytics({
    required this.monthly,
    required this.yearly,
    required this.sipCount,
    required this.folioCount,
    required this.transactionCount,
    required this.totalInvestedOverTime,
    required this.totalRedeemed,
    required this.averageMonthlyInvestment,
    required this.activeMonths,
    this.firstInvestmentDate,
    this.bestHolding,
    this.weakestHolding,
  });

  /// Oldest → newest, at most [months] entries (gaps filled with zeroes).
  final List<MonthlyFlow> monthly;

  /// Newest → oldest.
  final List<YearFlow> yearly;

  final int sipCount;
  final int folioCount;
  final int transactionCount;
  final double totalInvestedOverTime;
  final double totalRedeemed;
  final double averageMonthlyInvestment;
  final int activeMonths;
  final DateTime? firstInvestmentDate;

  /// Strongest and weakest scheme by percentage return.
  final SchemeHolding? bestHolding;
  final SchemeHolding? weakestHolding;

  bool get isEmpty => transactionCount == 0;

  static const PortfolioAnalytics empty = PortfolioAnalytics(
    monthly: <MonthlyFlow>[],
    yearly: <YearFlow>[],
    sipCount: 0,
    folioCount: 0,
    transactionCount: 0,
    totalInvestedOverTime: 0,
    totalRedeemed: 0,
    averageMonthlyInvestment: 0,
    activeMonths: 0,
  );

  factory PortfolioAnalytics.from({
    required List<FundTransaction> transactions,
    required PortfolioSummary summary,
    DateTime? now,
    int months = 12,
  }) {
    if (transactions.isEmpty) return PortfolioAnalytics.empty;

    final clock = now ?? DateTime.now();
    final byMonth = <String, List<FundTransaction>>{};
    final byYear = <int, List<FundTransaction>>{};
    final folios = <String>{};
    var sipCount = 0;
    var invested = 0.0;
    var redeemed = 0.0;
    DateTime? firstDate;

    for (final transaction in transactions) {
      final date = transaction.transactionDate;
      final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(monthKey, () => <FundTransaction>[]).add(transaction);
      byYear.putIfAbsent(date.year, () => <FundTransaction>[]).add(transaction);

      if (transaction.folioNumber.trim().isNotEmpty) {
        folios.add(transaction.folioNumber.trim());
      }
      if (transaction.kind == TransactionKind.sip) sipCount++;
      if (transaction.kind.isInflow) invested += transaction.amount;
      if (transaction.kind.isOutflow) redeemed += transaction.amount;

      if (firstDate == null || date.isBefore(firstDate)) firstDate = date;
    }

    double totalFor(List<FundTransaction> rows, bool inflow) => rows
        .where((row) => inflow ? row.kind.isInflow : row.kind.isOutflow)
        .fold<double>(0, (sum, row) => sum + row.amount);

    /// Builds the last [months] calendar months ending with [clock]'s month.
    final monthly = <MonthlyFlow>[];
    final cursor = DateTime(clock.year, clock.month);
    for (var offset = months - 1; offset >= 0; offset--) {
      final month = DateTime(cursor.year, cursor.month - offset);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final rows = byMonth[key] ?? const <FundTransaction>[];
      monthly.add(
        MonthlyFlow(
          month: month,
          invested: totalFor(rows, true),
          redeemed: totalFor(rows, false),
          transactions: rows.length,
        ),
      );
    }

    final yearly = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    final holdings = summary.holdings
        .where((holding) => holding.investedAmount > 0)
        .toList(growable: false);

    SchemeHolding? best;
    SchemeHolding? weakest;
    for (final holding in holdings) {
      if (best == null || holding.pnlPercent > best.pnlPercent) best = holding;
      if (weakest == null || holding.pnlPercent < weakest.pnlPercent) {
        weakest = holding;
      }
    }

    final activeMonths =
        monthly.where((flow) => flow.transactions > 0).length;

    return PortfolioAnalytics(
      monthly: List<MonthlyFlow>.unmodifiable(monthly),
      yearly: List<YearFlow>.unmodifiable(
        yearly.map(
          (year) => YearFlow(
            year: year,
            invested: totalFor(byYear[year]!, true),
            redeemed: totalFor(byYear[year]!, false),
            transactions: byYear[year]!.length,
          ),
        ),
      ),
      sipCount: sipCount,
      folioCount: folios.length,
      transactionCount: transactions.length,
      totalInvestedOverTime: invested,
      totalRedeemed: redeemed,
      averageMonthlyInvestment: activeMonths == 0 ? 0 : invested / activeMonths,
      activeMonths: activeMonths,
      firstInvestmentDate: firstDate,
      bestHolding: best,
      weakestHolding: weakest,
    );
  }
}
