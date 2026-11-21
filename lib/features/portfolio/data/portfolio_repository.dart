import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../domain/nav_quote.dart';
import '../domain/portfolio_calculator.dart';
import '../domain/portfolio_summary.dart';
import 'nav_repository.dart';

/// Orchestrates the two data sources the P&L engine needs: CAMS transactions
/// from Firestore and live NAVs from MFAPI.
class PortfolioRepository {
  PortfolioRepository({
    required TransactionRepository transactions,
    required NavRepository navs,
    PortfolioCalculator calculator = const PortfolioCalculator(),
  })  : _transactions = transactions,
        _navs = navs,
        _calculator = calculator;

  final TransactionRepository _transactions;
  final NavRepository _navs;
  final PortfolioCalculator _calculator;

  /// Used by the admin directory for clients who are not signed in.
  Future<PortfolioSummary> forPan(String pan) async {
    final transactions = await _transactions.fetchForPan(pan);
    return fromTransactions(transactions);
  }

  /// Used by the investor dashboard with an already-streamed transaction list.
  Future<PortfolioSummary> fromTransactions(
    List<FundTransaction> transactions,
  ) async {
    if (transactions.isEmpty) return PortfolioSummary.empty;

    final codes = <int>{
      for (final transaction in transactions)
        if (transaction.schemeCode > 0) transaction.schemeCode,
    };
    final quotes = await _navs.latestNavBatch(codes);

    final navByKey = <String, NavQuote>{
      for (final quote in quotes.values)
        PortfolioCalculator.schemeKeyForCode(quote.schemeCode): quote,
    };

    // The CAMS R9/R10 feed carries only the RTA scheme code, so these rows
    // have no AMFI code. Resolve it from the scheme name to keep live
    // valuation and P&L working.
    final uncodedNames = <String>{
      for (final transaction in transactions)
        if (transaction.schemeCode <= 0 &&
            transaction.schemeName.trim().isNotEmpty)
          transaction.schemeName,
    };

    if (uncodedNames.isNotEmpty) {
      final namedQuotes = await Future.wait(
        uncodedNames.map(
          (name) async => MapEntry<String, NavQuote?>(
            name,
            await _navs.latestNavForName(name),
          ),
        ),
      );

      for (final entry in namedQuotes) {
        final quote = entry.value;
        if (quote == null) continue;
        navByKey[PortfolioCalculator.schemeKeyForName(entry.key)] = quote;
      }
    }

    return _calculator.calculate(
      transactions: transactions,
      navByKey: navByKey,
    );
  }
}
