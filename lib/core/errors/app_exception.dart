import 'package:firebase_auth/firebase_auth.dart';

import 'api_exception.dart';

/// A failure that is safe to show to an investor or the admin.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  /// Translates the Firebase exceptions we expect into readable copy. Anything
  /// unknown falls back to a generic message so internals never leak into the UI.
  static String describe(Object error) {
    if (error is AppException) return error.message;

    // The backend already returns user-safe copy for its own failures.
    if (error is ApiException) return error.message;

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled. Contact $supportAddress.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account already exists for this email. Try signing in.';
        case 'weak-password':
          return 'Choose a stronger password (at least 8 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a minute and try again.';
        case 'network-request-failed':
          return 'Network unavailable. Check your connection and retry.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled for this project.';
        default:
          return error.message ?? 'Sign-in failed. Please try again.';
      }
    }

    return 'Something went wrong. Please try again.';
  }
}

const String supportAddress = 'fundmfservices@gmail.com';
