/// A failed call to the Fundmf HTTP API (Express on Render).
///
/// [message] is already safe to show to a user: the repository translates HTTP
/// statuses and network failures before throwing.
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode});

  final String message;

  /// Machine code from the server body (`unauthenticated`, `permission-denied`,
  /// `conflict`, `failed-precondition`, ...) or a client-side code such as
  /// `network` / `timeout`.
  final String? code;

  final int? statusCode;

  @override
  String toString() => message;
}
