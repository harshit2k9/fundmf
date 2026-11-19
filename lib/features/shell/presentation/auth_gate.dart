import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../admin/presentation/admin_shell.dart';
import '../../auth/domain/session.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/presentation/pending_approval_screen.dart';
import '../../auth/presentation/session_providers.dart';
import '../../auth/presentation/splash_screen.dart';
import 'app_shell.dart';

/// Single routing decision point for the whole app. Keeping this declarative
/// means a login, logout or admin approval immediately re-routes the UI.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return switch (session) {
      AsyncData<Session>(:final value) => _screenFor(value),
      AsyncError<Session>(:final error) => Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ErrorView(
                title: 'Could not start your session',
                message: AppException.describe(error),
                onRetry: () => ref.invalidate(sessionProvider),
              ),
            ),
          ),
        ),
      _ => const SplashScreen(),
    };
  }

  Widget _screenFor(Session session) {
    return switch (session.status) {
      SessionStatus.signedOut => const LoginScreen(),
      SessionStatus.unprovisioned =>
        PendingApprovalScreen(email: session.email),
      SessionStatus.pendingApproval => PendingApprovalScreen(
          email: session.email,
          profile: session.profile,
        ),
      SessionStatus.active => const AppShell(),
      SessionStatus.admin => const AdminShell(),
    };
  }
}
