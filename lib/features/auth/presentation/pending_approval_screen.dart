import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/support_mail.dart';
import '../../users/domain/user_profile.dart';
import 'session_providers.dart';

/// Shown when a signed-in email has no Fundmf profile, or has one that the
/// admin has not approved yet. No dashboard access is possible from here.
class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({
    super.key,
    required this.email,
    this.profile,
  });

  final String email;
  final UserProfile? profile;

  bool get _hasProfile => profile != null;

  Future<void> _requestAccess(BuildContext context) async {
    final opened = await openSupportEmail(
      subject: 'Fundmf access request — $email',
      body: <String>[
        'Hello Fundmf team,',
        '',
        _hasProfile
            ? 'My account is registered but still shows as pending approval.'
            : 'Please provision a Fundmf profile for my email address.',
        '',
        'Registered email: $email',
        if (profile != null) 'PAN on file: ${profile!.pan}',
        if (profile != null) 'Client ID: ${profile!.clientId}',
        '',
        'Thank you.',
      ].join('\n'),
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No mail app available. Write to ${AppConstants.supportEmail}.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            'F',
                            style: TextStyle(
                              color: AppColors.goldSoft,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amberWash,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'PENDING',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Icon(
                      _hasProfile
                          ? Icons.hourglass_top_rounded
                          : Icons.person_search_rounded,
                      size: 30,
                      color: AppColors.amber,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _hasProfile
                          ? 'Account pending admin approval'
                          : 'This email is not registered yet',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _hasProfile
                          ? 'Your profile exists but the Fundmf admin has not '
                              'approved access yet. You will be able to see your '
                              'portfolio as soon as approval is completed.'
                          : 'Fundmf is invite-only. The admin must create your '
                              'client profile with your email and PAN before you '
                              'can view a portfolio.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.slate,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'SIGNED IN AS',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (profile != null) ...<Widget>[
                            const SizedBox(height: 12),
                            const Text(
                              'PAN ON FILE',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              profile!.pan,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => _requestAccess(context),
                      icon: const Icon(Icons.mail_outline_rounded, size: 18),
                      label: const Text('Contact Fundmf admin'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref.invalidate(sessionProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking your profile status…'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh status'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(authRepositoryProvider).signOut();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('Sign out'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Support: ${AppConstants.supportEmail}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slateLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
