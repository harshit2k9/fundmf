import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/api_exception.dart';
import '../domain/sync_result.dart';

/// Admin-only operations: triggering the Gmail/CAMS pipeline on the Fundmf API
/// (Express on Render) and reading its audit trail from Firestore.
class AdminRepository {
  AdminRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    http.Client? client,
    String baseUrl = AppConstants.apiBaseUrl,
  })  : _auth = auth,
        _firestore = firestore,
        _client = client ?? http.Client(),
        // A trailing slash in the define would produce '//api/...' and a 404.
        _baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 120);

  /// Calls `POST /api/cams/sync` with the admin's Firebase ID token.
  ///
  /// Authentication stays in Firebase; the server verifies the token with the
  /// Admin SDK and rejects anyone who is not the admin account.
  Future<SyncResult> triggerManualSync() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ApiException(
        'Your session expired. Sign in again to run the sync.',
        code: 'unauthenticated',
        statusCode: 401,
      );
    }

    final idToken = await user.getIdToken();
    final uri = Uri.parse('$_baseUrl${AppConstants.syncPath}');

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, String>{'trigger': 'manual'}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'The sync is taking longer than expected. It may still finish — '
        'check the sync log in a minute.',
        code: 'timeout',
      );
    } catch (_) {
      throw const ApiException(
        'Could not reach the Fundmf API. Check your connection, or that the '
        'Render service is running.',
        code: 'network',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return SyncResult.fromMap(Map<String, dynamic>.from(decoded));
        }
      } on FormatException {
        // A proxy or error page returned 200 with a non-JSON body.
      }
      throw const ApiException('The sync API returned an unexpected response.');
    }

    throw ApiException(
      _messageFor(response),
      code: 'http-${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  /// Prefers the server's human-readable message, with a fallback per status.
  String _messageFor(http.Response response) {
    String? serverMessage;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          serverMessage = message.trim();
        }
      }
    } catch (_) {
      // Non-JSON body (proxy error page): fall through to the status text.
    }

    switch (response.statusCode) {
      case 401:
        return 'Your session expired. Sign in again to run the sync.';
      case 403:
        return 'Only the Fundmf admin account can run the CAMS sync.';
      case 404:
        return serverMessage ??
            'The sync endpoint was not found. Check AppConstants.apiBaseUrl.';
      case 409:
        return serverMessage ??
            'A sync is already running. Try again in a minute.';
      case 429:
        return serverMessage ??
            'Too many sync requests. Wait a minute and try again.';
      case 503:
        return serverMessage ??
            'The server is missing its Gmail credentials or is starting up.';
      default:
        return serverMessage ??
            'The sync failed (HTTP ${response.statusCode}).';
    }
  }

  Stream<List<SyncLogEntry>> watchLogs({int limit = 25}) {
    return _firestore
        .collection(FirestorePaths.syncLogs)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => SyncLogEntry.fromMap(doc.data(), documentId: doc.id),
              )
              .toList(growable: false),
        );
  }
}
