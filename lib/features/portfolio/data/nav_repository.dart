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
  final Map<String, _CachedNav> _nameCache = <String, _CachedNav>{};
  final Map<String, DateTime> _nameMisses = <String, DateTime>{};
  final Map<String, Future<int?>> _codeLookups = <String, Future<int?>>{};

  static final DateFormat _mfApiDate = DateFormat('dd-MM-yyyy');

  /// Words that describe the plan rather than the fund, so they are ignored
  /// when matching a CAMS scheme name against MFAPI results.
  static const Set<String> _stopWords = <String>{
    'fund',
    'plan',
    'scheme',
    'option',
    'mutual',
    'regular',
    'direct',
    'growth',
    'idcw',
    'dividend',
    'payout',
    'reinvestment',
    'the',
    'and',
    'of',
    'to',
    'formerly',
    'known',
    'as',
  };

  static final RegExp _wordSplit = RegExp(r'[^a-z0-9]+');

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

  /// Latest NAV for a scheme that has no AMFI code in the statement.
  ///
  /// The CAMS R9/R10 feed only carries the RTA scheme code, so the AMFI code
  /// is resolved from the scheme name first. Successful matches are cached
  /// like any other quote; misses back off for [_cacheTtl].
  Future<NavQuote?> latestNavForName(String schemeName) async {
    final key = _nameKey(schemeName);
    if (key.isEmpty) return null;

    final cached = _nameCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.quote;
    }

    final missedAt = _nameMisses[key];
    if (missedAt != null && DateTime.now().difference(missedAt) < _cacheTtl) {
      return null;
    }

    final code = await _resolveSchemeCode(key, schemeName);
    if (code == null) {
      _nameMisses[key] = DateTime.now();
      return null;
    }

    final quote = await latestNav(code);
    if (quote == null) return null;
    _nameCache[key] = _CachedNav(quote);
    return quote;
  }

  String _nameKey(String schemeName) => schemeName.trim().toLowerCase();

  Future<int?> _resolveSchemeCode(String key, String schemeName) async {
    final pending = _codeLookups[key];
    if (pending != null) return pending;

    final future = _searchSchemeCode(schemeName);
    _codeLookups[key] = future;
    final code = await future;
    // Do not cache a transient failure (offline) for the whole session.
    if (code == null) _codeLookups.remove(key);
    return code;
  }

  Future<int?> _searchSchemeCode(String schemeName) async {
    final tokens = _tokens(schemeName);
    if (tokens.isEmpty) return null;

    final queries = <String>{
      tokens.take(8).join(' '),
      tokens.take(5).join(' '),
    }.where((query) => query.isNotEmpty);

    for (final query in queries) {
      final uri = Uri.parse('${AppConstants.mfApiBaseUrl}/search')
          .replace(queryParameters: <String, String>{'q': query});
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;

        final code = _bestMatch(schemeName, jsonDecode(response.body));
        if (code != null) return code;
      } catch (_) {
        // Offline or malformed payload: try again on the next dashboard load.
        return null;
      }
    }

    return null;
  }

  /// Picks the closest regular-plan growth scheme from the search results.
  int? _bestMatch(String schemeName, dynamic body) {
    if (body is! List) return null;

    final target = _tokens(schemeName).toSet();
    if (target.isEmpty) return null;

    final lower = schemeName.toLowerCase();
    final wantRegular = lower.contains('regular') || !lower.contains('direct');
    final wantGrowth = lower.contains('growth') || !lower.contains('idcw');

    int? bestCode;
    var bestScore = 0;
    var bestOverlap = 0;

    for (final item in body) {
      if (item is! Map) continue;
      final code = item['schemeCode'];
      final name = item['schemeName'];
      if (code is! int || name is! String) continue;

      final candidateTokens = _tokens(name).toSet();
      final overlap = target.intersection(candidateTokens).length;
      if (overlap == 0) continue;

      final candidate = name.toLowerCase();
      var score = overlap * 10;
      if (wantRegular && candidate.contains('regular')) score += 6;
      if (!wantRegular && candidate.contains('direct')) score += 6;
      if (wantRegular && candidate.contains('direct')) score -= 8;
      if (wantGrowth && candidate.contains('growth')) score += 6;
      // Prefer the exact scheme over a longer look-alike (e.g. an "Omni FOF"
      // variant of the same fund house).
      score -= (candidateTokens.length - overlap).clamp(0, 5).toInt() * 2;
      if (!wantGrowth &&
          (candidate.contains('idcw') || candidate.contains('dividend'))) {
        score += 4;
      }

      if (score > bestScore || (score == bestScore && overlap > bestOverlap)) {
        bestScore = score;
        bestOverlap = overlap;
        bestCode = code;
      }
    }

    // One shared word (usually the fund house) is not enough to trust.
    return bestOverlap >= 2 ? bestCode : null;
  }

  /// Significant, de-duplicated words of a scheme name, in order.
  List<String> _tokens(String name) {
    var cleaned = name.toLowerCase();
    final formerly = cleaned.indexOf('(formerly');
    if (formerly > 0) cleaned = cleaned.substring(0, formerly);

    final seen = <String>{};
    final tokens = <String>[];
    for (final word in cleaned.split(_wordSplit)) {
      if (word.length < 2 || _stopWords.contains(word)) continue;
      if (seen.add(word)) tokens.add(word);
    }
    return tokens;
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
