import 'dart:math' as math;

import '../../transactions/domain/transaction_model.dart';
import 'nav_quote.dart';
import 'portfolio_summary.dart';
import 'scheme_holding.dart';

/// Deterministic portfolio maths, isolated from Firebase and Flutter so it can
/// be unit tested and reused by the admin directory.
///
/// Accounting method: **average cost**. Units and cost basis are accumulated in
/// chronological order. A redemption reduces units and removes
/// `units × average NAV at that moment` of principal, which mirrors how AMCs
/// report gains on a consolidated statement.
class PortfolioCalculator {
  const PortfolioCalculator();

  static const double _unitEpsilon = 0.0001;

  /// Stable key used to join transactions with live NAV quotes.
  static String schemeKeyForCode(int schemeCode) => 'code:$schemeCode';

  static String schemeKeyForName(String schemeName) =>
      'name:${schemeName.trim().toUpperCase()}';

  static String schemeKeyOf(FundTransaction transaction) {
    if (transaction.schemeCode > 0) {
      return schemeKeyForCode(transaction.schemeCode);
    }
    return schemeKeyForName(transaction.schemeName);
  }

  /// Builds the full summary from CAMS transactions and (optionally) live NAVs.
  /// [navByKey] is keyed with [schemeKeyOf].
  PortfolioSummary calculate({
    required List<FundTransaction> transactions,
    Map<String, NavQuote> navByKey = const <String, NavQuote>{},
  }) {
    if (transactions.isEmpty) return PortfolioSummary.empty;

    // Chronological order is required for the average-cost running balance.
    final ordered = List<FundTransaction>.of(transactions)
      ..sort((a, b) {
        final byDate = a.transactionDate.compareTo(b.transactionDate);
        return byDate != 0 ? byDate : a.transactionId.compareTo(b.transactionId);
      });

    final buckets = <String, _SchemeAccumulator>{};

    for (final transaction in ordered) {
      final key = schemeKeyOf(transaction);
      final bucket = buckets.putIfAbsent(
        key,
        () => _SchemeAccumulator(
          key: key,
          schemeCode: transaction.schemeCode,
          schemeName: transaction.schemeName,
        ),
      );

      if (bucket.schemeName.isEmpty && transaction.schemeName.isNotEmpty) {
        bucket.schemeName = transaction.schemeName;
      }
      if (transaction.folioNumber.isNotEmpty &&
          !bucket.folios.contains(transaction.folioNumber)) {
        bucket.folios.add(transaction.folioNumber);
      }

      if (transaction.kind.isInflow) {
        final units = transaction.units.abs();
        var amount = transaction.amount.abs();
        // Some statement variants only carry units + NAV.
        if (amount == 0 && units > 0 && transaction.purchaseNav > 0) {
          amount = units * transaction.purchaseNav;
        }
        bucket.units += units;
        bucket.costBasis += amount;
      } else if (transaction.kind.isOutflow) {
        _applyRedemption(bucket, transaction.units.abs());
      }
      // `other` rows (STT, dividends, segregation) never change units or cost.
    }

    final holdings = <SchemeHolding>[];

    for (final bucket in buckets.values) {
      if (bucket.units <= _unitEpsilon) continue;

      final quote = navByKey[bucket.key];
      final averageNav = bucket.units > 0 ? bucket.costBasis / bucket.units : 0.0;
      final currentNav = quote?.nav ?? averageNav;
      final currentValue = bucket.units * currentNav;
      final pnl = currentValue - bucket.costBasis;

      holdings.add(
        SchemeHolding(
          schemeCode: bucket.schemeCode,
          schemeName: bucket.schemeName,
          folios: List<String>.unmodifiable(bucket.folios),
          units: bucket.units,
          investedAmount: bucket.costBasis,
          averageNav: averageNav,
          currentNav: currentNav,
          currentValue: currentValue,
          pnl: pnl,
          pnlPercent: bucket.costBasis > 0 ? (pnl / bucket.costBasis) * 100 : 0,
          allocationPercent: 0,
          navAvailable: quote != null,
          navDate: quote?.date,
        ),
      );
    }

    holdings.sort((a, b) => b.currentValue.compareTo(a.currentValue));

    final totalValue = holdings.fold<double>(0, (sum, h) => sum + h.currentValue);
    final totalInvested =
        holdings.fold<double>(0, (sum, h) => sum + h.investedAmount);
    final totalUnits = holdings.fold<double>(0, (sum, h) => sum + h.units);
    final absolutePnl = totalValue - totalInvested;

    return PortfolioSummary(
      totalInvested: totalInvested,
      currentValue: totalValue,
      absolutePnl: absolutePnl,
      returnPercent: totalInvested > 0 ? (absolutePnl / totalInvested) * 100 : 0,
      totalUnits: totalUnits,
      holdings: holdings
          .map(
            (holding) => holding.copyWith(
              allocationPercent: totalValue > 0
                  ? (holding.currentValue / totalValue) * 100
                  : 0,
            ),
          )
          .toList(growable: false),
      closedSchemes: buckets.length - holdings.length,
      hasLiveNav: holdings.any((holding) => holding.navAvailable),
      asOf: DateTime.now(),
    );
  }

  /// Removes redeemed units at the running average cost. Over-redemptions are
  /// clamped so a malformed statement can never produce negative units.
  void _applyRedemption(_SchemeAccumulator bucket, double units) {
    if (units <= 0 || bucket.units <= _unitEpsilon) return;
    final averageNav = bucket.costBasis / bucket.units;
    final principal = math.min(units * averageNav, bucket.costBasis);
    bucket.costBasis = math.max(0.0, bucket.costBasis - principal);
    bucket.units = math.max(0.0, bucket.units - units);
  }
}

class _SchemeAccumulator {
  _SchemeAccumulator({
    required this.key,
    required this.schemeCode,
    required this.schemeName,
  });

  final String key;
  final int schemeCode;
  String schemeName;
  final List<String> folios = <String>[];
  double units = 0;
  double costBasis = 0;
}
