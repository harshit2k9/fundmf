import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/support_mail.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../users/domain/user_profile.dart';

/// Read-only investor profile. Edits are requested by email because the admin
/// owns the client record.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showPan = false;
  bool _changingPassword = false;

  Future<void> _requestUpdate(UserProfile profile) async {
    final opened = await openSupportEmail(
      subject: 'Profile update request — ${profile.fullName}',
      body: <String>[
        'Hello Fundmf team,',
        '',
        'Please update my Fundmf profile.',
        '',
        'Client ID: ${profile.clientId}',
        'Full name: ${profile.fullName}',
        'Registered email: ${profile.email}',
        'Phone: ${profile.phone}',
        'PAN: ${profile.pan}',
        '',
        'Requested change: ',
        '',
        'Thank you.',
      ].join('\n'),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No mail app available. Write to ${AppConstants.supportEmail}.',
          ),
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: currentController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.coralDeep,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _changingPassword
                      ? null
                      : () async {
                          if (newController.text != confirmController.text) {
                            setDialogState(() => error = 'Passwords do not match.');
                            return;
                          }
                          if (newController.text.length < 6) {
                            setDialogState(() =>
                                error = 'Password must be at least 6 characters.');
                            return;
                          }
                          setState(() => _changingPassword = true);
                          try {
                            await ref
                                .read(authRepositoryProvider)
                                .changePassword(
                                  currentPassword: currentController.text,
                                  newPassword: newController.text,
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (e) {
                            setDialogState(() => error = 'Could not change password. Check current password.');
                          } finally {
                            if (mounted) setState(() => _changingPassword = false);
                          }
                        },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    final session = ref.watch(activeSessionProvider);

    if (profile == null) {
      return const Center(child: Text('Profile unavailable'));
    }

    final (badgeColor, badgeWash, badgeIcon) = switch (profile.status) {
      AccountStatus.active => (
          AppColors.emeraldDeep,
          AppColors.emeraldWash,
          Icons.verified_rounded,
        ),
      AccountStatus.pendingApproval => (
          const Color(0xFFB45309),
          AppColors.amberWash,
          Icons.hourglass_top_rounded,
        ),
      AccountStatus.unclaimed => (
          AppColors.slate,
          const Color(0xFFF1F5F9),
          Icons.person_outline_rounded,
        ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          profile.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              profile.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              profile.email,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.slate,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: <Widget>[
                                StatusBadge(
                                  label: profile.statusLabel,
                                  color: badgeColor,
                                  wash: badgeWash,
                                  icon: badgeIcon,
                                ),
                                StatusBadge(
                                  label: 'Client ${profile.clientId}',
                                  color: AppColors.navy,
                                  wash: AppColors.canvas,
                                  icon: Icons.badge_outlined,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Personal details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InfoRow(
                        label: 'Full name',
                        value: profile.fullName,
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Registered email',
                        value: profile.email,
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Phone number',
                        value: profile.phone.isEmpty ? '—' : profile.phone,
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'PAN number',
                        value:
                            _showPan ? profile.pan : Formatters.maskPan(profile.pan),
                        monospace: true,
                        trailing: IconButton(
                          tooltip: _showPan ? 'Hide PAN' : 'Show PAN',
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _showPan = !_showPan),
                          icon: Icon(
                            _showPan
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Client ID',
                        value: profile.clientId.isEmpty ? '—' : profile.clientId,
                        monospace: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InfoRow(
                        label: 'Status',
                        value: profile.statusLabel,
                        valueColor: badgeColor,
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Linked on',
                        value: Formatters.date(profile.linkedAt),
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Profile created',
                        value: Formatters.date(profile.createdAt),
                      ),
                      const Divider(height: 1),
                      InfoRow(
                        label: 'Sign-in',
                        value: session.user?.email ?? profile.email,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Need a change?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Profile fields are maintained by the Fundmf admin. Send '
                        'a pre-filled request and we will update your record.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.slate,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _changingPassword ? null : _changePassword,
                        icon: const Icon(Icons.lock_reset_rounded, size: 18),
                        label: const Text('Change password'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _requestUpdate(profile),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Request profile update'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 17),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Fundmf · Mutual fund portfolio tracking. Data sourced from '
                  'CAMS statements and AMFI NAVs. Not investment advice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.slateLight,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
