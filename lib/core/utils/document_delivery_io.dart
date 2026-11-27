import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'document_delivery_contract.dart';

/// Mobile & desktop delivery.
///
/// The user is always asked where to save: the platform's own save dialog
/// (Android Storage Access Framework, the iOS document picker, or a desktop
/// file dialog) is opened, so a report never lands in an app-private cache
/// folder the user cannot reach. If the dialog cannot be shown on a platform,
/// the file is written to the share directory and handed to the native share
/// sheet instead.
class DocumentDelivery {
  const DocumentDelivery();

  Future<DeliveryResult> deliver({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String subject,
    required String text,
  }) async {
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save $fileName',
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
      );
      if (saved == null) {
        return const DeliveryResult(
          delivered: false,
          message: 'Export cancelled — no file was saved.',
        );
      }
      return DeliveryResult(
        delivered: true,
        location: saved.path.isEmpty ? saved.toString() : saved.path,
      );
    } on Object {
      // No save dialog on this platform: fall back to the share sheet, which
      // still lets the user pick Files, Drive or an email.
      return _share(bytes: bytes, fileName: fileName, mimeType: mimeType,
          subject: subject, text: text);
    }
  }

  Future<DeliveryResult> _share({
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
      return DeliveryResult(
        delivered: false,
        location: file.path,
        message: 'The report was saved to ${file.path}.',
      );
    }
  }

  /// The file is written to `<cache>/share_plus` because that directory is the
  /// one share_plus serves on Android; writing elsewhere triggers
  /// "Failed to find configured root".
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
