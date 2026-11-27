import 'dart:typed_data';

import 'document_delivery_contract.dart';

/// Fallback used when neither `dart:io` nor the JS interop library is present.
class DocumentDelivery {
  const DocumentDelivery();

  Future<DeliveryResult> deliver({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
    required String text,
  }) async {
    throw UnsupportedError(
      'Saving documents is not supported on this platform.',
    );
  }
}
