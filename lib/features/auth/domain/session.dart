import 'package:firebase_auth/firebase_auth.dart';

import '../../users/domain/user_profile.dart';

/// What the auth gate should render right now.
enum SessionStatus {
  /// No Firebase session.
  signedOut,

  /// Signed in, but the admin has not provisioned this email.
  unprovisioned,

  /// Provisioned and linked, but `isApproved` is false.
  pendingApproval,

  /// Provisioned, linked and approved.
  active,

  /// The Fundmf service account.
  admin,
}

/// Combined Firebase Auth + Firestore state. The gate consumes only this.
class Session {
  const Session({required this.status, this.user, this.profile});

  final SessionStatus status;
  final User? user;
  final UserProfile? profile;

  bool get isAdmin => status == SessionStatus.admin;

  bool get canAccessApp =>
      status == SessionStatus.active || status == SessionStatus.admin;

  String get email => user?.email ?? profile?.email ?? '';

  static const Session signedOut = Session(status: SessionStatus.signedOut);
}
