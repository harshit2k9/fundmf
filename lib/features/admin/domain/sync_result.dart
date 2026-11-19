import '../../../core/utils/firestore_parsing.dart';

/// Summary returned by `POST /api/cams/sync` on the Fundmf API.
class SyncResult {
  const SyncResult({
    required this.status,
    required this.messagesScanned,
    required this.attachmentsParsed,
    required this.transactionsCreated,
    required this.duplicatesSkipped,
    required this.errors,
    required this.durationMs,
    this.trigger = 'manual',
  });

  factory SyncResult.fromMap(Map<String, dynamic> map) {
    return SyncResult(
      status: asString(map['status']).isEmpty ? 'unknown' : asString(map['status']),
      messagesScanned: asInt(map['messagesScanned']),
      attachmentsParsed: asInt(map['attachmentsParsed']),
      transactionsCreated: asInt(map['transactionsCreated']),
      duplicatesSkipped: asInt(map['duplicatesSkipped']),
      errors: (map['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map((error) => error.toString())
          .toList(growable: false),
      durationMs: asInt(map['durationMs']),
      trigger: asString(map['trigger']).isEmpty ? 'manual' : asString(map['trigger']),
    );
  }

  final String status;
  final int messagesScanned;
  final int attachmentsParsed;
  final int transactionsCreated;
  final int duplicatesSkipped;
  final List<String> errors;
  final int durationMs;
  final String trigger;

  bool get isSuccess => status == 'success';

  static const SyncResult empty = SyncResult(
    status: 'unknown',
    messagesScanned: 0,
    attachmentsParsed: 0,
    transactionsCreated: 0,
    duplicatesSkipped: 0,
    errors: <String>[],
    durationMs: 0,
  );
}

/// A `sync_logs/{id}` document written by the sync service.
class SyncLogEntry {
  const SyncLogEntry({
    required this.id,
    required this.status,
    required this.trigger,
    this.startedAt,
    this.finishedAt,
    this.messagesScanned = 0,
    this.transactionsCreated = 0,
    this.duplicatesSkipped = 0,
    this.errors = const <String>[],
    this.actor = '',
    this.errorMessage = '',
    this.durationMs = 0,
  });

  factory SyncLogEntry.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return SyncLogEntry(
      id: documentId ?? '',
      status: asString(map['status']),
      trigger: asString(map['trigger']),
      startedAt: asDateTime(map['startedAt']),
      finishedAt: asDateTime(map['finishedAt']),
      messagesScanned: asInt(map['messagesScanned']),
      transactionsCreated: asInt(map['transactionsCreated']),
      duplicatesSkipped: asInt(map['duplicatesSkipped']),
      errors: (map['errors'] as List<dynamic>? ?? const <dynamic>[])
          .map((error) => error.toString())
          .toList(growable: false),
      actor: asString(map['actor']),
      errorMessage: asString(map['errorMessage']),
      durationMs: asInt(map['durationMs']),
    );
  }

  final String id;
  final String status;
  final String trigger;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int messagesScanned;
  final int transactionsCreated;
  final int duplicatesSkipped;
  final List<String> errors;
  final String actor;
  final String errorMessage;
  final int durationMs;

  bool get isSuccess => status == 'success';
}
