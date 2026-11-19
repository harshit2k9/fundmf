import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_providers.dart';
import '../../users/domain/user_profile.dart';
import '../data/admin_repository.dart';
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
