import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore hands back several representations for the same logical value
/// depending on who wrote the document (Cloud Function vs. Flutter vs. console).
/// These helpers normalise them once so models stay simple.

DateTime? asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text) ?? parseCamsDate(text);
  }
  return null;
}

double asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final text = value
      .toString()
      .replaceAll(',', '')
      .replaceAll('₹', '')
      .replaceAll('Rs.', '')
      .trim();
  return double.tryParse(text) ?? 0;
}

int asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString().trim()) ?? 0;
}

String asString(dynamic value) => value?.toString().trim() ?? '';

/// CAMS statements use `dd-MMM-yyyy`, `dd/MM/yyyy` and `yyyy-MM-dd` depending on
/// the file variant. Returns `null` when the text is not a date.
DateTime? parseCamsDate(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;

  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }

  final numeric = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(value);
  if (numeric != null) {
    final day = int.parse(numeric.group(1)!);
    final month = int.parse(numeric.group(2)!);
    var year = int.parse(numeric.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }

  final named = RegExp(r'^(\d{1,2})-([A-Za-z]{3,})-(\d{2,4})').firstMatch(value);
  if (named != null) {
    const months = <String>[
      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
      'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
    ];
    final month = months.indexOf(named.group(2)!.toLowerCase()) + 1;
    if (month == 0) return null;
    final day = int.parse(named.group(1)!);
    var year = int.parse(named.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }

  return DateTime.tryParse(value);
}
