/// Latest NAV published by AMFI for a scheme (via api.mfapi.in).
class NavQuote {
  const NavQuote({
    required this.schemeCode,
    required this.schemeName,
    required this.fundHouse,
    required this.nav,
    required this.date,
  });

  final int schemeCode;
  final String schemeName;
  final String fundHouse;
  final double nav;
  final DateTime date;
}
