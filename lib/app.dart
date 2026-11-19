import 'package:material_ui/material_ui.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/firebase_setup_screen.dart';
import 'features/shell/presentation/auth_gate.dart';

class FundmfApp extends StatelessWidget {
  const FundmfApp({super.key, this.bootstrapError});

  final Object? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: bootstrapError == null
          ? const AuthGate()
          : FirebaseSetupScreen(error: bootstrapError!),
    );
  }
}
