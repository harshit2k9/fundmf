import 'package:intl/intl.dart';

/// Formatting helpers. All money in Fundmf is INR, displayed with Indian digit
/// grouping (1,23,456.78).
abstract final class Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _compactCurrency = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static final NumberFormat _plainAmount = NumberFormat('#,##,##0.00', 'en_IN');

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _shortDate = DateFormat('dd MMM');
  static final DateFormat _stamp = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _isoDate = DateFormat('dd/MM/yyyy');

  /// `₹1,23,456.78`
  static String currency(num? value) => _currency.format(value ?? 0).trim();

  /// `₹1.2L` — used inside compact chart labels.
  static String compactCurrency(num? value) =>
      _compactCurrency.format(value ?? 0).trim();

  /// `₹1,23,456.78` without the rupee glyph (PDF fonts lack it).
  static String amountWithoutSymbol(num? value) =>
      _plainAmount.format(value ?? 0);

  /// `+₹1,234.00` / `-₹1,234.00`
  static String signedCurrency(num? value) {
    final v = value ?? 0;
    final sign = v > 0 ? '+' : (v < 0 ? '-' : '');
    return '$sign${currency(v.abs())}';
  }

  /// `+12.34%`
  static String signedPercent(num? value) {
    final v = value ?? 0;
    final sign = v > 0 ? '+' : (v < 0 ? '-' : '');
    return '$sign${v.abs().toStringAsFixed(2)}%';
  }

  /// `12.34%`
  static String percent(num? value) => '${(value ?? 0).toStringAsFixed(2)}%';

  /// Units are always shown to three decimals — AMFI folios track fractions.
  static String units(num? value) =>
      NumberFormat('#,##,##0.000', 'en_IN').format(value ?? 0);

  /// Four decimal places for NAVs, matching AMFI convention.
  static String nav(num? value) => (value ?? 0).toStringAsFixed(4);

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value);

  static String shortDate(DateTime? value) =>
      value == null ? '—' : _shortDate.format(value);

  static String timestamp(DateTime? value) =>
      value == null ? '—' : _stamp.format(value);

  /// `November 2026` — used for the ledger's month separators.
  static String monthYear(DateTime? value) =>
      value == null ? '—' : _monthYear.format(value);

  static String isoDate(DateTime? value) =>
      value == null ? '—' : _isoDate.format(value);

  /// `ABCDE1234F` -> `ABCDE••••F`
  static String maskPan(String pan) {
    final value = pan.trim();
    // Keep the first five and the last character; anything shorter cannot be
    // masked without an out-of-range substring.
    if (value.length < 6) return value;
    return '${value.substring(0, 5)}••••${value.substring(value.length - 1)}';
  }

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static String greeting([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
