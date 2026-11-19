import 'scheme_holding.dart';

/// Aggregate portfolio figures plus the scheme-wise breakdown.
class PortfolioSummary {
  const PortfolioSummary({
    required this.totalInvested,
    required this.currentValue,
    required this.absolutePnl,
    required this.returnPercent,
    required this.totalUnits,
    required this.holdings,
    this.closedSchemes = 0,
    this.hasLiveNav = false,
    this.asOf,
  });

  /// Sum of inflow amounts minus redeemed principal (average-cost method).
  final double totalInvested;

  /// Σ (net active units × latest NAV) per scheme.
  final double currentValue;

  /// Current value − total invested.
  final double absolutePnl;

  /// (absolute P&L ÷ total invested) × 100.
  final double returnPercent;

  final double totalUnits;
  final List<SchemeHolding> holdings;

  /// Schemes that were fully redeemed and therefore no longer appear.
  final int closedSchemes;

  /// Whether at least one holding used a live MFAPI NAV.
  final bool hasLiveNav;

  /// When the calculation ran.
  final DateTime? asOf;

  static const PortfolioSummary empty = PortfolioSummary(
    totalInvested: 0,
    currentValue: 0,
    absolutePnl: 0,
    returnPercent: 0,
    totalUnits: 0,
    holdings: <SchemeHolding>[],
  );

  bool get isEmpty => holdings.isEmpty;
  bool get isProfit => absolutePnl >= 0;

  /// Round-tripping helper for the PDF/CSV exports.
  List<SchemeHolding> get sortedHoldings => holdings;
}
