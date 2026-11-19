import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../users/data/user_repository.dart';
import '../../users/domain/user_profile.dart';
import '../data/auth_repository.dart';
import '../domain/session.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

/// Resolves the whole onboarding gate from one stream:
///
/// * signed out                -> login
/// * no provisioned profile    -> "pending admin approval"
/// * profile not yet linked    -> link uid, then continue
/// * linked but not approved   -> "pending admin approval"
/// * linked + approved         -> dashboard
/// * admin email               -> admin panel
final sessionProvider = StreamProvider<Session>((ref) async* {
  final auth = ref.watch(authRepositoryProvider);
  final users = ref.watch(userRepositoryProvider);

  await for (final user in auth.authStateChanges) {
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      yield Session.signedOut;
      continue;
    }

    final normalizedEmail = Validators.normalizeEmail(email);

    if (normalizedEmail == AppConstants.adminEmail) {
      yield Session(status: SessionStatus.admin, user: user);
      continue;
    }

    UserProfile? profile;
    try {
      profile = await users.fetchProfile(normalizedEmail);
    } catch (_) {
      // Firestore unavailable: treat as unprovisioned rather than crashing.
      profile = null;
    }

    if (profile == null) {
      yield Session(status: SessionStatus.unprovisioned, user: user);
      continue;
    }

    if (profile.uid.isEmpty) {
      // First login for an admin-provisioned email: claim the profile.
      try {
        await users.linkAuthUser(email: normalizedEmail, uid: user.uid);
        profile = profile.copyWith(uid: user.uid, linkedAt: DateTime.now());
      } catch (_) {
        // The next auth event or a manual refresh retries the link.
      }
    } else if (profile.uid != user.uid) {
      // Already claimed by a different auth account.
      yield Session(status: SessionStatus.unprovisioned, user: user);
      continue;
    }

    yield Session(
      status: profile.isApproved
          ? SessionStatus.active
          : SessionStatus.pendingApproval,
      user: user,
      profile: profile,
    );
  }
});

/// The signed-in investor's profile (null for admin / signed-out).
final activeProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(sessionProvider).value?.profile;
});

final activeSessionProvider = Provider<Session>((ref) {
  return ref.watch(sessionProvider).value ?? Session.signedOut;
});
