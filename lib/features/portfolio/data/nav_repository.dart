import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/nav_quote.dart';

/// Fetches the latest NAV for an AMFI scheme code from api.mfapi.in.
///
/// MFAPI publishes one JSON document per scheme whose `data` array is ordered
/// newest-first. Quotes are cached for [AppConstants.navCacheTtl] and identical
/// concurrent requests share a single HTTP call — the dashboard rebuilds on
/// every transaction snapshot, so this matters.
class NavRepository {
  NavRepository({
    http.Client? client,
    Duration cacheTtl = AppConstants.navCacheTtl,
  })  : _client = client ?? http.Client(),
        _cacheTtl = cacheTtl;

  final http.Client _client;
  final Duration _cacheTtl;
  final Map<int, _CachedNav> _cache = <int, _CachedNav>{};
  final Map<int, Future<NavQuote?>> _inFlight = <int, Future<NavQuote?>>{};

  static final DateFormat _mfApiDate = DateFormat('dd-MM-yyyy');

  /// Returns the latest quote, or null when the scheme is unknown/offline.
  Future<NavQuote?> latestNav(int schemeCode) async {
    if (schemeCode <= 0) return null;

    final cached = _cache[schemeCode];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.quote;
    }

    final pending = _inFlight[schemeCode];
    if (pending != null) return pending;

    final future = _fetch(schemeCode);
    _inFlight[schemeCode] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(schemeCode);
    }
  }

  /// Fetches many schemes in small parallel chunks so a large portfolio does
  /// not open dozens of sockets at once.
  Future<Map<int, NavQuote>> latestNavBatch(
    Iterable<int> schemeCodes, {
    int chunkSize = 6,
  }) async {
    final unique = schemeCodes.where((code) => code > 0).toSet().toList()
      ..sort();
    final result = <int, NavQuote>{};

    for (var start = 0; start < unique.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, unique.length);
      final chunk = unique.sublist(start, end);
      final quotes = await Future.wait(
        chunk.map((code) => latestNav(code)),
      );
      for (var i = 0; i < chunk.length; i++) {
        final quote = quotes[i];
        if (quote != null) result[chunk[i]] = quote;
      }
    }

    return result;
  }

  Future<NavQuote?> _fetch(int schemeCode) async {
    try {
      final response = await _client
          .get(Uri.parse('${AppConstants.mfApiBaseUrl}/$schemeCode'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final meta = body['meta'];
      final data = body['data'];
      if (data is! List || data.isEmpty) return null;

      final latest = data.first;
      if (latest is! Map) return null;

      final navText = (latest['nav'] ?? '').toString().replaceAll(',', '').trim();
      final nav = double.tryParse(navText);
      final date = _mfApiDate.tryParse((latest['date'] ?? '').toString().trim());
      if (nav == null || nav <= 0 || date == null) return null;

      final metaMap = meta is Map ? meta : const <String, dynamic>{};
      final quote = NavQuote(
        schemeCode: schemeCode,
        schemeName: (metaMap['scheme_name'] ?? '').toString(),
        fundHouse: (metaMap['fund_house'] ?? '').toString(),
        nav: nav,
        date: date,
      );
      _cache[schemeCode] = _CachedNav(quote);
      return quote;
    } catch (_) {
      // Offline or malformed payload: keep the portfolio usable without a NAV.
      return null;
    }
  }

  void dispose() => _client.close();
}

class _CachedNav {
  _CachedNav(this.quote) : fetchedAt = DateTime.now();

  final NavQuote quote;
  final DateTime fetchedAt;
}
