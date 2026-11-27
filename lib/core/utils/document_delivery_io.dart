import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'document_delivery_contract.dart';

/// Mobile & desktop delivery: write the report into the app cache and hand it
/// to the native share sheet ("Save to Files", "Save to Drive", email, …).
///
/// The file is written to `<cache>/share_plus` because that directory is the
/// one share_plus serves on Android; writing elsewhere triggers
/// "Failed to find configured root".
class DocumentDelivery {
  const DocumentDelivery();

  Future<DeliveryResult> deliver({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
    required String text,
  }) async {
    final file = await _writeCacheFile(fileName, bytes);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(file.path, mimeType: mimeType, name: fileName),
          ],
          subject: subject,
          text: text,
        ),
      );
      if (result.status == ShareResultStatus.unavailable) {
        return DeliveryResult(
          delivered: false,
          location: file.path,
          message: 'The share sheet is unavailable. The report was saved to '
              '${file.path}.',
        );
      }
      return DeliveryResult(delivered: true, location: file.path);
    } on Object {
      // A denied/absent share sheet must not look like a failed export: the
      // document is already generated and on disk.
      return DeliveryResult(
        delivered: false,
        location: file.path,
        message: 'The report was saved to ${file.path}.',
      );
    }
  }

  Future<File> _writeCacheFile(String fileName, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final shareDir = Directory('${directory.path}/share_plus');
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }
    final file = File('${shareDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
