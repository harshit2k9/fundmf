import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';

/// Opens the device mail client pre-addressed to the Fundmf service inbox.
/// Returns false when no mail app is available (common on desktop web).
Future<bool> openSupportEmail({
  required String subject,
  required String body,
}) async {
  final uri = Uri.parse(
    'mailto:${AppConstants.supportEmail}'
    '?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}',
  );
  try {
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}
