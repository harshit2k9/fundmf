import '../../../core/utils/firestore_parsing.dart';

/// CAMS transaction categories that matter to portfolio maths.
enum TransactionKind {
  purchase('Purchase', 'Purchase'),
  sip('SIP', 'SIP'),
  redemption('Redemption', 'Redemption'),
  switchIn('Switch-In', 'Switch in'),
  switchOut('Switch-Out', 'Switch out'),
  other('Other', 'Other');

  const TransactionKind(this.label, this.displayName);

  final String label;
  final String displayName;

  /// Money and units moving into the portfolio.
  bool get isInflow =>
      this == TransactionKind.purchase ||
      this == TransactionKind.sip ||
      this == TransactionKind.switchIn;

  /// Money and units leaving a scheme.
  bool get isOutflow =>
      this == TransactionKind.redemption || this == TransactionKind.switchOut;

  /// Normalises the many spellings found in CAMS statement files into the
  /// six canonical kinds used by the app.
  static TransactionKind fromCams(String rawType) {
    final value = rawType.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (value.isEmpty) return TransactionKind.other;

    if (value.contains('switch') || value.contains('switching')) {
      if (value.contains('out')) return TransactionKind.switchOut;
      if (value.contains('in')) return TransactionKind.switchIn;
    }
    if (value.contains('redemption') || value.contains('redeem')) {
      return TransactionKind.redemption;
    }
    if (value.contains('systematic') ||
        value.contains('sip') ||
        value.contains('sipinstallment')) {
      return TransactionKind.sip;
    }
    if (value.contains('purchase') ||
        value.contains('investment') ||
        value.contains('subscription') ||
        value.contains('allotment')) {
      return TransactionKind.purchase;
    }
    return TransactionKind.other;
  }
}

/// A single row from a CAMS consolidated account statement.
///
/// The document id equals [transactionId], which makes the sync service's
/// writes idempotent: re-processing the same email can never double count.
class FundTransaction {
  const FundTransaction({
    required this.id,
    required this.transactionId,
    required this.pan,
    required this.schemeName,
    required this.transactionDate,
    required this.kind,
    required this.amount,
    required this.units,
    required this.purchaseNav,
    this.uid = '',
    this.folioNumber = '',
    this.schemeCode = 0,
    this.rawType = '',
    this.sourceMessageId = '',
    this.processedAt,
  });

  factory FundTransaction.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final storedId = asString(map['transactionId']);
    return FundTransaction(
      id: documentId ?? (storedId.isEmpty ? '' : storedId),
      transactionId: storedId.isEmpty ? (documentId ?? '') : storedId,
      pan: asString(map['pan']).toUpperCase(),
      uid: asString(map['uid']),
      folioNumber: asString(map['folioNumber']),
      schemeName: asString(map['schemeName']),
      schemeCode: asInt(map['schemeCode']),
      transactionDate:
          asDateTime(map['transactionDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      kind: TransactionKind.fromCams(asString(map['transactionType'])),
      rawType: asString(map['transactionType']),
      amount: asDouble(map['amount']),
      units: asDouble(map['units']),
      purchaseNav: asDouble(map['purchaseNav']),
      sourceMessageId: asString(map['sourceMessageId']),
      processedAt: asDateTime(map['processedAt']),
    );
  }

  final String id;
  final String transactionId;
  final String pan;

  /// Owning Firebase Auth uid. Empty when the PAN is not provisioned (yet).
  final String uid;
  final String folioNumber;
  final String schemeName;

  /// AMFI scheme code, used for the live NAV lookup. 0 when the statement did
  /// not include one.
  final int schemeCode;
  final DateTime transactionDate;
  final TransactionKind kind;
  final String rawType;

  /// Always stored as a positive INR value; [kind] carries the direction.
  final double amount;
  final double units;
  final double purchaseNav;

  final String sourceMessageId;
  final DateTime? processedAt;

  bool get isBuy => kind.isInflow;
  bool get isSell => kind.isOutflow;

  /// Units bought (+) or redeemed (-).
  double get signedUnits => kind.isOutflow ? -units : units;

  /// Amount bought (+) or redeemed (-).
  double get signedAmount => kind.isOutflow ? -amount : amount;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'transactionId': transactionId,
        'pan': pan,
        'uid': uid,
        'folioNumber': folioNumber,
        'schemeName': schemeName,
        'schemeCode': schemeCode,
        'transactionDate': transactionDate,
        'transactionType': kind.label,
        'amount': amount,
        'units': units,
        'purchaseNav': purchaseNav,
        'sourceMessageId': sourceMessageId,
      };
}
