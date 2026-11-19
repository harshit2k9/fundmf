import '../../../core/utils/firestore_parsing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';

/// Lifecycle of a provisioned client profile.
enum AccountStatus {
  unclaimed,
  pendingApproval,
  active,
}

/// A `users/{email}` document.
///
/// The admin provisions the profile *before* the investor signs in, so [uid] is
/// empty until the first successful login links the Firebase Auth account.
class UserProfile {
  const UserProfile({
    required this.email,
    required this.fullName,
    required this.pan,
    required this.phone,
    this.uid = '',
    this.isApproved = false,
    this.clientId = '',
    this.createdAt,
    this.linkedAt,
    this.lastLoginAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final rawEmail = asString(map['email']);
    return UserProfile(
      email: Validators.normalizeEmail(rawEmail.isEmpty ? (documentId ?? '') : rawEmail),
      fullName: asString(map['fullName']),
      pan: Validators.normalizePan(asString(map['pan'])),
      phone: asString(map['phone']),
      uid: asString(map['uid']),
      isApproved: map['isApproved'] == true,
      clientId: asString(map['clientId']),
      createdAt: asDateTime(map['createdAt']),
      linkedAt: asDateTime(map['linkedAt']),
      lastLoginAt: asDateTime(map['lastLoginAt']),
    );
  }

  final String email;
  final String fullName;
  final String pan;
  final String phone;

  /// Firebase Auth uid, empty until the investor claims the profile.
  final String uid;
  final bool isApproved;

  /// Human-readable identifier shown on the profile screen (FMF-XXXX).
  final String clientId;

  final DateTime? createdAt;
  final DateTime? linkedAt;
  final DateTime? lastLoginAt;

  bool get isLinked => uid.trim().isNotEmpty;

  AccountStatus get status {
    if (!isLinked) return AccountStatus.unclaimed;
    if (!isApproved) return AccountStatus.pendingApproval;
    return AccountStatus.active;
  }

  String get statusLabel => switch (status) {
        AccountStatus.unclaimed => 'Unclaimed',
        AccountStatus.pendingApproval => 'Pending approval',
        AccountStatus.active => 'Active',
      };

  String get maskedPan => Formatters.maskPan(pan);

  String get initials => Formatters.initials(fullName);

  /// Profile fields only — timestamps are stamped server-side by the repository
  /// so we never overwrite `createdAt` with a client clock value.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'email': email,
        'fullName': fullName,
        'pan': pan,
        'phone': phone,
        'uid': uid,
        'isApproved': isApproved,
        'clientId': clientId,
      };

  UserProfile copyWith({
    String? email,
    String? fullName,
    String? pan,
    String? phone,
    String? uid,
    bool? isApproved,
    String? clientId,
    DateTime? createdAt,
    DateTime? linkedAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      pan: pan ?? this.pan,
      phone: phone ?? this.phone,
      uid: uid ?? this.uid,
      isApproved: isApproved ?? this.isApproved,
      clientId: clientId ?? this.clientId,
      createdAt: createdAt ?? this.createdAt,
      linkedAt: linkedAt ?? this.linkedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
