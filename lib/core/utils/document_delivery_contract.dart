/// What happened when a generated document was handed to the platform.
class DeliveryResult {
  const DeliveryResult({required this.delivered, this.location, this.message});

  /// True when the OS share sheet / browser download accepted the file.
  final bool delivered;

  /// Where the file lives when the platform did not take over (e.g. the share
  /// sheet is unavailable and the file stayed in the app cache).
  final String? location;

  final String? message;
}
