import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A misconfigured Firebase project should surface as an actionable setup
  // screen, not a white crash screen.
  Object? bootstrapError;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (error) {
    bootstrapError = error;
  }

  runApp(
    ProviderScope(
      child: FundmfApp(bootstrapError: bootstrapError),
    ),
  );
}
