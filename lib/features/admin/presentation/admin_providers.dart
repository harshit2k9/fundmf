import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_providers.dart';
import '../../portfolio/domain/portfolio_summary.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../users/domain/user_profile.dart';
import '../data/admin_repository.dart';
import '../domain/client_portfolio.dart';
import '../domain/sync_result.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  ),
);

/// All provisioned clients, searchable in the admin directory.
final adminClientsProvider = StreamProvider<List<UserProfile>>(
  (ref) => ref.watch(userRepositoryProvider).watchAllProfiles(),
);

/// Recent CAMS sync runs (newest first).
final adminSyncLogsProvider = StreamProvider<List<SyncLogEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).watchLogs(),
);

/// Every client joined with their live portfolio valuation.
///
/// Valuations reuse the shared NAV cache, so refreshing the overview is cheap
/// after the first load. A failing client never breaks the directory: their
/// summary simply stays empty.
final adminClientPortfoliosProvider =
    FutureProvider<List<AdminClientPortfolio>>((ref) async {
  final clients = await ref.watch(adminClientsProvider.future);
  final repository = ref.watch(portfolioRepositoryProvider);
  final rows = <AdminClientPortfolio>[];

  for (final client in clients) {
    PortfolioSummary summary = PortfolioSummary.empty;
    if (client.pan.trim().isNotEmpty) {
      try {
        summary = await repository.forPan(client.pan);
      } catch (_) {
        // Offline or a Firestore index gap: keep the directory usable.
      }
    }
    rows.add(AdminClientPortfolio(client: client, summary: summary));
  }

  return rows;
});

/// Book of business totals for the admin overview.
final adminTotalsProvider = FutureProvider<AdminTotals>((ref) async {
  final rows = await ref.watch(adminClientPortfoliosProvider.future);
  return AdminTotals.from(rows);
});

/// Clients waiting for approval, oldest profile first.
final adminPendingClientsProvider = Provider<List<UserProfile>>((ref) {
  final clients = ref.watch(adminClientsProvider).value ?? const <UserProfile>[];
  return clients
      .where((client) => client.status == AccountStatus.pendingApproval)
      .toList(growable: false);
});
