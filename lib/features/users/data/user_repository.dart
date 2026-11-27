import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../domain/user_profile.dart';

/// Reads and writes `users/{email}` documents.
///
/// Investors can only read their own document and may only write the three
/// link fields; all structural writes go through the admin methods below.
class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  DocumentReference<Map<String, dynamic>> docFor(String email) =>
      _users.doc(Validators.normalizeEmail(email));

  /// Live profile for the signed-in investor (null when unprovisioned).
  Stream<UserProfile?> watchProfile(String email) {
    return docFor(email).snapshots().map(_toProfile);
  }

  Future<UserProfile?> fetchProfile(String email) async {
    final snapshot = await docFor(email).get();
    return _toProfile(snapshot);
  }

  /// Called once, on the investor's first login: binds the Firebase Auth uid to
  /// the pre-provisioned profile.
  Future<void> linkAuthUser({
    required String email,
    required String uid,
  }) async {
    await docFor(email).update(<String, dynamic>{
      'uid': uid,
      'linkedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> touchLastLogin(String email) async {
    await docFor(email).update(<String, dynamic>{
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------- admin ---

  Stream<List<UserProfile>> watchAllProfiles() {
    return _users.orderBy('fullName').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => UserProfile.fromMap(doc.data(), documentId: doc.id))
              .where((profile) => profile.email != AppConstants.adminEmail)
              .toList(growable: false),
        );
  }

  Future<bool> emailExists(String email) async =>
      (await docFor(email).get()).exists;

  Future<void> createProfile(UserProfile profile) async {
    final email = Validators.normalizeEmail(profile.email);
    final doc = _users.doc(email);
    if ((await doc.get()).exists) {
      throw const AppException(
        'A client with this email already exists.',
        code: 'email-in-use',
      );
    }
    final clientId =
        profile.clientId.trim().isEmpty ? generateClientId() : profile.clientId;
    final normalized = profile.copyWith(
      email: email,
      pan: Validators.normalizePan(profile.pan),
      clientId: clientId,
    );
    await doc.set(<String, dynamic>{
      ...normalized.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Email is the document id, so it is intentionally immutable after creation.
  Future<void> updateProfile(UserProfile profile) async {
    final normalized = profile.copyWith(
      pan: Validators.normalizePan(profile.pan),
    );
    await docFor(profile.email).update(<String, dynamic>{
      ...normalized.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProfile(String email) => docFor(email).delete();

  /// Admin approval switch. A pending client becomes active immediately and
  /// the session stream re-routes them into the app.
  Future<void> setApproval(String email, bool approved) async {
    await docFor(email).update(<String, dynamic>{
      'isApproved': approved,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static String generateClientId() {
    final now = DateTime.now();
    final code = now.millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final suffix = code.length >= 5 ? code.substring(code.length - 5) : code;
    return 'FMF-${now.year}-$suffix';
  }

  UserProfile? _toProfile(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return UserProfile.fromMap(data, documentId: snapshot.id);
  }
}
