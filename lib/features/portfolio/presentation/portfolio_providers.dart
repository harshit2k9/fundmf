import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_providers.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction_model.dart';
import '../data/nav_repository.dart';
import '../data/portfolio_repository.dart';
import '../domain/portfolio_calculator.dart';
import '../domain/portfolio_summary.dart';

final navRepositoryProvider = Provider<NavRepository>((ref) {
  final repository = NavRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(firestoreProvider)),
);

final portfolioCalculatorProvider = Provider<PortfolioCalculator>(
  (ref) => const PortfolioCalculator(),
);

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => PortfolioRepository(
    transactions: ref.watch(transactionRepositoryProvider),
    navs: ref.watch(navRepositoryProvider),
    calculator: ref.watch(portfolioCalculatorProvider),
  ),
);

/// Live CAMS transactions for the signed-in investor, newest first.
final transactionFeedProvider = StreamProvider<List<FundTransaction>>((ref) {
  final pan = ref.watch(activeProfileProvider)?.pan ?? '';
  return ref.watch(transactionRepositoryProvider).watchForPan(pan);
});

/// Portfolio figures derived from Firestore transactions + live MFAPI NAVs.
final portfolioSummaryProvider = FutureProvider<PortfolioSummary>((ref) async {
  final transactions = await ref.watch(transactionFeedProvider.future);
  if (transactions.isEmpty) return PortfolioSummary.empty;
  return ref.watch(portfolioRepositoryProvider).fromTransactions(transactions);
});

/// Admin directory summary for a client's PAN (works without their session).
final clientPortfolioProvider =
    FutureProvider.autoDispose.family<PortfolioSummary, String>((ref, pan) async {
  if (pan.trim().isEmpty) return PortfolioSummary.empty;
  return ref.watch(portfolioRepositoryProvider).forPan(pan);
});
