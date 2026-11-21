import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../portfolio/domain/portfolio_summary.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../users/domain/user_profile.dart';
import 'admin_client_form_screen.dart';
import 'admin_providers.dart';

/// Searchable directory of every provisioned client profile.
class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openForm([UserProfile? existing]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminClientFormScreen(existing: existing),
      ),
    );
  }

  List<UserProfile> _filter(List<UserProfile> clients, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return clients;
    return clients
        .where(
          (client) =>
              client.fullName.toLowerCase().contains(needle) ||
              client.email.toLowerCase().contains(needle) ||
              client.pan.toLowerCase().contains(needle) ||
              client.clientId.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(adminClientsProvider);
    final query = _search.text;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search name, email, PAN or client ID',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 18),
                        label: const Text('New client'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AsyncValueView<List<UserProfile>>(
                    asyncValue: clientsAsync,
                    loading: const SizedBox.shrink(),
                    builder: (clients) {
                      final active = clients
                          .where((c) => c.status == AccountStatus.active)
                          .length;
                      final unclaimed = clients
                          .where((c) => c.status == AccountStatus.unclaimed)
                          .length;
                      return Text(
                        '${clients.length} clients  ·  $active active  ·  '
                        '$unclaimed unclaimed',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.slate,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueView<List<UserProfile>>(
                asyncValue: clientsAsync,
                onRetry: () => ref.invalidate(adminClientsProvider),
                builder: (clients) {
                  final filtered = _filter(clients, query);
                  if (clients.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No clients provisioned',
                      message:
                          'Create the first client profile to grant portfolio '
                          'access.',
                    );
                  }
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching clients',
                      message: 'Try a different name, email, PAN or client ID.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final client = filtered[index];
                      return _ClientCard(
                        client: client,
                        onEdit: () => _openForm(client),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({required this.client, required this.onEdit});

  final UserProfile client;
  final VoidCallback onEdit;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete client profile?'),
        content: Text(
          '${client.fullName} will immediately lose access to Fundmf. Their '
          'imported CAMS transactions are kept for audit purposes.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coralDeep,
              minimumSize: const Size(96, 44),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(userRepositoryProvider).deleteProfile(client.email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${client.fullName} removed')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this client.')),
      );
    }
  }

  void _showDetails(BuildContext context, UserProfile client) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ClientDetailDialog(client: client),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (badgeColor, badgeWash) = switch (client.status) {
      AccountStatus.active => (AppColors.emeraldDeep, AppColors.emeraldWash),
      AccountStatus.pendingApproval => (
          const Color(0xFFB45309),
          AppColors.amberWash,
        ),
      AccountStatus.unclaimed => (AppColors.slate, const Color(0xFFF1F5F9)),
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  client.initials,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      client.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  StatusBadge(
                    label: client.statusLabel,
                    color: badgeColor,
                    wash: badgeWash,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    client.pan,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ClientPortfolio(pan: client.pan),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Client ${client.clientId.isEmpty ? '—' : client.clientId}'
                  '  ·  ${client.phone.isEmpty ? 'No phone' : client.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.slateLight,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showDetails(context, client),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Details'),
              ),
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit'),
              ),
              IconButton(
                tooltip: 'Delete client',
                visualDensity: VisualDensity.compact,
                onPressed: () => _delete(context, ref),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: AppColors.coralDeep,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientPortfolio extends ConsumerWidget {
  const _ClientPortfolio({required this.pan});

  final String pan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(clientPortfolioProvider(pan));

    return switch (summaryAsync) {
      AsyncData<PortfolioSummary>(:final value) when value.isEmpty => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'No CAMS transactions imported yet',
            style: TextStyle(fontSize: 11, color: AppColors.slate),
          ),
        ),
      AsyncData<PortfolioSummary>(:final value) => Row(
          children: <Widget>[
            Expanded(
              child: _MiniStat(
                label: 'Invested',
                value: Formatters.currency(value.totalInvested),
              ),
            ),
            Expanded(
              child: _MiniStat(
                label: 'Current',
                value: Formatters.currency(value.currentValue),
              ),
            ),
            Expanded(
              child: _MiniStat(
                label: 'P&L',
                value: Formatters.signedPercent(value.returnPercent),
                color: AppColors.forChange(value.absolutePnl),
              ),
            ),
            Expanded(
              child: _MiniStat(
                label: 'Schemes',
                value: '${value.holdings.length}',
              ),
            ),
          ],
        ),
      AsyncError<PortfolioSummary>() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.coralWash,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Portfolio summary unavailable',
            style: TextStyle(fontSize: 11, color: AppColors.coralDeep),
          ),
        ),
      _ => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: <Widget>[
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
              SizedBox(width: 8),
              Text(
                'Valuing portfolio…',
                style: TextStyle(fontSize: 11, color: AppColors.slate),
              ),
            ],
          ),
        ),
    };
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: AppColors.slateLight),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}


class _ClientDetailDialog extends ConsumerWidget {
  const _ClientDetailDialog({required this.client});

  final UserProfile client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(clientPortfolioProvider(client.pan));
    return AlertDialog(
      title: Text(client.fullName),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DetailRow(label: 'Email', value: client.email),
              _DetailRow(label: 'PAN', value: client.pan),
              _DetailRow(label: 'Phone', value: client.phone.isEmpty ? '—' : client.phone),
              _DetailRow(label: 'Client ID', value: client.clientId.isEmpty ? '—' : client.clientId),
              _DetailRow(label: 'Status', value: client.statusLabel),
              const SizedBox(height: 12),
              const Text(
                'Portfolio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 6),
              switch (summaryAsync) {
                AsyncData<PortfolioSummary>(:final value) when value.isEmpty =>
                  const Text('No transactions imported yet.'),
                AsyncData<PortfolioSummary>(:final value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Invested: ${Formatters.currency(value.totalInvested)}'),
                      Text('Current: ${Formatters.currency(value.currentValue)}'),
                      Text('P&L: ${Formatters.currency(value.absolutePnl)} (${Formatters.signedPercent(value.returnPercent)})'),
                      Text('Schemes: ${value.holdings.length}'),
                      const SizedBox(height: 8),
                      for (final holding in value.holdings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${holding.schemeName} — ${Formatters.currency(holding.currentValue)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                AsyncError<PortfolioSummary>() =>
                  const Text('Portfolio summary unavailable.'),
                _ => const Row(
                    children: <Widget>[
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Valuing portfolio…'),
                    ],
                  ),
              },
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
