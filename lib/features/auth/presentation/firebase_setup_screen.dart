import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

/// Shown when `Firebase.initializeApp` fails — almost always because
/// `lib/firebase_options.dart` still holds placeholders.
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Fundmf setup',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Firebase is not configured for this build yet.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Run the following once, then rebuild the app:',
                  style: TextStyle(color: AppColors.slate, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyDeep,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SelectableText(
                    'flutterfire configure --project=fundmf\n'
                    'firebase deploy --only firestore:rules,firestore:indexes,functions\n'
                    'firebase functions:secrets:set GMAIL_REFRESH_TOKEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Details: $error',
                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                ),
                const SizedBox(height: 24),
                Text(
                  'Need access? Ask the Fundmf admin at ${AppConstants.supportEmail}.',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
