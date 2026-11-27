import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/support_mail.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../users/domain/user_profile.dart';

/// Read-only investor profile. Profile edits are requested by email because the
/// admin owns the client record; security settings are self-service.
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
                            setDialogState(
                              () => error = 'Passwords do not match.',
                            );
                            return;
                          }
                          if (newController.text.length < 6) {
                            setDialogState(() => error =
                                'Password must be at least 6 characters.');
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
                          } catch (_) {
                            setDialogState(() => error =
                                'Could not change password. Check current password.');
                          } finally {
                            if (mounted) {
                              setState(() => _changingPassword = false);
                            }
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
    final summary = ref.watch(portfolioSummaryProvider).value;

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
          AppColors.amber,
          AppColors.amberWash,
          Icons.hourglass_top_rounded,
        ),
      AccountStatus.unclaimed => (
          AppColors.slate,
          AppColors.surfaceMuted,
          Icons.person_outline_rounded,
        ),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _IdentityCard(
                  profile: profile,
                  badgeColor: badgeColor,
                  badgeWash: badgeWash,
                  badgeIcon: badgeIcon,
                ),
                const SizedBox(height: 14),
                if (summary != null && !summary.isEmpty) ...<Widget>[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SectionHeader(
                          eyebrow: 'Snapshot',
                          title: 'Your portfolio at a glance',
                          subtitle: 'Live from your CAMS ledger',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: _SnapshotStat(
                                label: 'Current value',
                                value: Formatters.currency(summary.currentValue),
                              ),
                            ),
                            Expanded(
                              child: _SnapshotStat(
                                label: 'Invested',
                                value:
                                    Formatters.currency(summary.totalInvested),
                              ),
                            ),
                            Expanded(
                              child: _SnapshotStat(
                                label: 'Returns',
                                value: Formatters.signedPercent(
                                  summary.returnPercent,
                                ),
                                color: AppColors.forChange(summary.absolutePnl),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionHeader(
                        eyebrow: 'KYC',
                        title: 'Personal details',
                        subtitle: 'Maintained by the Fundmf admin',
                      ),
                      const SizedBox(height: 8),
                      InfoRow(label: 'Full name', value: profile.fullName),
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
                        value: _showPan
                            ? profile.pan
                            : Formatters.maskPan(profile.pan),
                        monospace: true,
                        trailing: IconButton(
                          tooltip: _showPan ? 'Hide PAN' : 'Show PAN',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => _showPan = !_showPan),
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
                        value:
                            profile.clientId.isEmpty ? '—' : profile.clientId,
                        monospace: true,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionHeader(
                        eyebrow: 'Access',
                        title: 'Account & security',
                        subtitle: 'Invite-only access, verified by email',
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SectionHeader(
                        eyebrow: 'Support',
                        title: 'Need a change?',
                        subtitle:
                            'Profile fields are maintained by the Fundmf admin',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Send a pre-filled request and we will update your '
                        'record. Password changes are instant.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _changingPassword ? null : _changePassword,
                        icon: const Icon(Icons.lock_reset_rounded, size: 17),
                        label: const Text('Change password'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _requestUpdate(profile),
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Request profile update'),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Fundmf · Wealth management for provisions-only clients.\n'
                  'Data sourced from CAMS / KFintech statements and AMFI NAVs. '
                  'Not investment advice.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.slateLight,
                    height: 1.6,
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.badgeColor,
    required this.badgeWash,
    required this.badgeIcon,
  });

  final UserProfile profile;
  final Color badgeColor;
  final Color badgeWash;
  final IconData badgeIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.inkDeep, AppColors.ink, AppColors.inkSoft],
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: AppColors.goldSoft,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: <Widget>[
                    StatusBadge(
                      label: profile.statusLabel,
                      color: badgeColor,
                      wash: badgeWash,
                      icon: badgeIcon,
                      dense: true,
                    ),
                    StatusBadge(
                      label: 'Client ${profile.clientId.isEmpty ? '—' : profile.clientId}',
                      color: Colors.white,
                      wash: Colors.white.withValues(alpha: 0.1),
                      icon: Icons.badge_outlined,
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotStat extends StatelessWidget {
  const _SnapshotStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.slateLight,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.ink,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
