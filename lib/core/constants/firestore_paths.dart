/// Firestore collection names. Document identifiers are documented next to
/// each collection so the Cloud Function, rules and Flutter code agree.
abstract final class FirestorePaths {
  /// `users/{email}` — email is lower-cased and doubles as the document id so
  /// the admin can provision a profile before the investor ever signs in.
  static const String users = 'users';

  /// `transactions/{transactionId}` — the CAMS `Transaction_ID` is the document
  /// id, which gives us idempotent writes for free.
  static const String transactions = 'transactions';

  /// `sync_logs/{autoId}` — one entry per scheduled/manual CAMS sync run.
  static const String syncLogs = 'sync_logs';
}
