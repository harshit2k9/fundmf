import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../domain/transaction_model.dart';

/// Reads the `transactions` collection.
///
/// Queries are always scoped by PAN. That matches the security rule that lets
/// an investor read transactions for their own PAN even before the Cloud
/// Function has stamped their uid onto the documents.
class TransactionRepository {
  TransactionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection(FirestorePaths.transactions);

  Stream<List<FundTransaction>> watchForPan(String pan, {int limit = 500}) {
    final normalized = pan.trim().toUpperCase();
    if (normalized.isEmpty) {
      return Stream<List<FundTransaction>>.value(const <FundTransaction>[]);
    }
    return _transactions
        .where('pan', isEqualTo: normalized)
        .orderBy('transactionDate', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapSnapshot);
  }

  Future<List<FundTransaction>> fetchForPan(String pan, {int limit = 500}) async {
    final normalized = pan.trim().toUpperCase();
    if (normalized.isEmpty) return const <FundTransaction>[];
    final snapshot = await _transactions
        .where('pan', isEqualTo: normalized)
        .orderBy('transactionDate', descending: true)
        .limit(limit)
        .get();
    return _mapSnapshot(snapshot);
  }

  List<FundTransaction> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) => FundTransaction.fromMap(doc.data(), documentId: doc.id))
        .toList(growable: false);
  }
}
