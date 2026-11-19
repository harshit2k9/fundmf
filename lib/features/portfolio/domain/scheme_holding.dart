/// One scheme currently held by an investor, with everything the holdings card
/// and the allocation chart need.
class SchemeHolding {
  const SchemeHolding({
    required this.schemeCode,
    required this.schemeName,
    required this.folios,
    required this.units,
    required this.investedAmount,
    required this.averageNav,
    required this.currentNav,
    required this.currentValue,
    required this.pnl,
    required this.pnlPercent,
    required this.allocationPercent,
    required this.navAvailable,
    this.navDate,
  });

  final int schemeCode;
  final String schemeName;
  final List<String> folios;

  /// Net active units (purchases + switches in − redemptions − switches out).
  final double units;

  /// Remaining cost basis after deducting redeemed principal (average-cost).
  final double investedAmount;
  final double averageNav;
  final double currentNav;
  final double currentValue;
  final double pnl;
  final double pnlPercent;
  final double allocationPercent;

  /// False when MFAPI had no quote — the app then falls back to average NAV so
  /// the portfolio still renders instead of failing the whole screen.
  final bool navAvailable;
  final DateTime? navDate;

  String get folioLabel => folios.isEmpty ? '—' : folios.join(', ');

  String get shortName {
    if (schemeName.length <= 36) return schemeName;
    return '${schemeName.substring(0, 33)}…';
  }

  SchemeHolding copyWith({double? allocationPercent}) {
    return SchemeHolding(
      schemeCode: schemeCode,
      schemeName: schemeName,
      folios: folios,
      units: units,
      investedAmount: investedAmount,
      averageNav: averageNav,
      currentNav: currentNav,
      currentValue: currentValue,
      pnl: pnl,
      pnlPercent: pnlPercent,
      allocationPercent: allocationPercent ?? this.allocationPercent,
      navAvailable: navAvailable,
      navDate: navDate,
    );
  }
}
