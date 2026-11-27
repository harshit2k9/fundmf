import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../users/domain/user_profile.dart';
import '../domain/client_portfolio.dart';
import 'admin_client_form_screen.dart';
import 'admin_providers.dart';

enum _ClientFilter { all, active, pending, unclaimed }

enum _ClientSort { name, aum, returns }

/// Searchable directory of every provisioned client, with status filters,
/// live AUM and one-tap approval.
class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() => _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  final _search = TextEditingController();
  _ClientFilter _filter = _ClientFilter.all;
  _ClientSort _sort = _ClientSort.name;

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

  List<AdminClientPortfolio> _apply(List<AdminClientPortfolio> rows) {
    final needle = _search.text.trim().toLowerCase();
    final filtered = rows.where((row) {
      final client = row.client;
      final matchesStatus = switch (_filter) {
        _ClientFilter.all => true,
        _ClientFilter.active => client.status == AccountStatus.active,
        _ClientFilter.pending =>
          client.status == AccountStatus.pendingApproval,
        _ClientFilter.unclaimed => client.status == AccountStatus.unclaimed,
      };
      if (!matchesStatus) return false;
      if (needle.isEmpty) return true;
      return client.fullName.toLowerCase().contains(needle) ||
          client.email.toLowerCase().contains(needle) ||
          client.pan.toLowerCase().contains(needle) ||
          client.clientId.toLowerCase().contains(needle);
    }).toList();

    switch (_sort) {
      case _ClientSort.name:
        filtered.sort((a, b) => a.client.fullName.compareTo(b.client.fullName));
      case _ClientSort.aum:
        filtered.sort(
          (a, b) =>
              b.summary.currentValue.compareTo(a.summary.currentValue),
        );
      case _ClientSort.returns:
        filtered.sort(
          (a, b) => b.summary.returnPercent.compareTo(a.summary.returnPercent),
        );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(adminClientPortfoliosProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                                const Icon(Icons.search_rounded, size: 19),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.close_rounded,
                                        size: 17),
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
                          minimumSize: const Size(0, 46),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 17),
                        label: const Text('New client'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: <Widget>[
                              _FilterChip(
                                label: 'All',
                                selected: _filter == _ClientFilter.all,
                                onSelected: () => setState(
                                  () => _filter = _ClientFilter.all,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Active',
                                selected: _filter == _ClientFilter.active,
                                onSelected: () => setState(
                                  () => _filter = _ClientFilter.active,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Pending approval',
                                selected: _filter == _ClientFilter.pending,
                                onSelected: () => setState(
                                  () => _filter = _ClientFilter.pending,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Unclaimed',
                                selected: _filter == _ClientFilter.unclaimed,
                                onSelected: () => setState(
                                  () => _filter = _ClientFilter.unclaimed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<_ClientSort>(
                        tooltip: 'Sort clients',
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (context) =>
                            const <PopupMenuEntry<_ClientSort>>[
                          PopupMenuItem<_ClientSort>(
                            value: _ClientSort.name,
                            child: Text('By name'),
                          ),
                          PopupMenuItem<_ClientSort>(
                            value: _ClientSort.aum,
                            child: Text('By portfolio value'),
                          ),
                          PopupMenuItem<_ClientSort>(
                            value: _ClientSort.returns,
                            child: Text('By return %'),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.swap_vert_rounded, size: 15),
                              SizedBox(width: 4),
                              Text(
                                'Sort',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AsyncValueView<List<AdminClientPortfolio>>(
                    asyncValue: rowsAsync,
                    loading: const SizedBox.shrink(),
                    builder: (rows) {
                      final totals = AdminTotals.from(rows);
                      return Text(
                        '${totals.clients} clients  ·  ${totals.active} active  ·  '
                        '${totals.pending} pending  ·  '
                        '${Formatters.currency(totals.aum)} managed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueView<List<AdminClientPortfolio>>(
                asyncValue: rowsAsync,
                onRetry: () => ref.invalidate(adminClientPortfoliosProvider),
                builder: (rows) {
                  if (rows.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No clients provisioned',
                      message:
                          'Create the first client profile to grant portfolio '
                          'access.',
                    );
                  }
                  final filtered = _apply(rows);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching clients',
                      message:
                          'Try a different search term, status filter or sort.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final row = filtered[index];
                      return _ClientCard(
                        row: row,
                        onEdit: () => _openForm(row.client),
                        onDetails: () =>
                            _showDetails(context, row),
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

  void _showDetails(BuildContext context, AdminClientPortfolio row) {
    showDialog<void>(
      context: context,
      builder: (_) => _ClientDossier(row: row),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.ink,
      ),
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? AppColors.ink : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _ClientCard extends ConsumerWidget {
  const _ClientCard({
    required this.row,
    required this.onEdit,
    required this.onDetails,
  });

  final AdminClientPortfolio row;
  final VoidCallback onEdit;
  final VoidCallback onDetails;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final client = row.client;
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
              minimumSize: const Size(96, 42),
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

  Future<void> _setApproval(
    BuildContext context,
    WidgetRef ref,
    bool approved,
  ) async {
    try {
      await ref
          .read(userRepositoryProvider)
          .setApproval(row.client.email, approved);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? '${row.client.fullName} approved'
                : '${row.client.fullName} moved to pending',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppException.describe(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = row.client;
    final (badgeColor, badgeWash) = switch (client.status) {
      AccountStatus.active => (AppColors.emeraldDeep, AppColors.emeraldWash),
      AccountStatus.pendingApproval => (AppColors.amber, AppColors.amberWash),
      AccountStatus.unclaimed => (AppColors.slate, AppColors.surfaceMuted),
    };
    final summary = row.summary;

    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  client.initials,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldSoft,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      client.fullName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
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
                    dense: true,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'PAN ${client.maskedPan}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: row.hasPortfolio
                ? Row(
                    children: <Widget>[
                      Expanded(
                        child: _MiniStat(
                          label: 'Current value',
                          value: Formatters.currency(summary.currentValue),
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: 'Invested',
                          value: Formatters.currency(summary.totalInvested),
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: 'Return',
                          value:
                              Formatters.signedPercent(summary.returnPercent),
                          color: AppColors.forChange(summary.absolutePnl),
                        ),
                      ),
                      Expanded(
                        child: _MiniStat(
                          label: 'Schemes',
                          value: '${summary.holdings.length}',
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'No CAMS transactions imported yet',
                    style: TextStyle(fontSize: 11, color: AppColors.slate),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Client ${client.clientId.isEmpty ? '—' : client.clientId}'
                  '  ·  ${client.phone.isEmpty ? 'No phone' : client.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.slateLight,
                  ),
                ),
              ),
              if (client.status == AccountStatus.pendingApproval)
                TextButton(
                  onPressed: () => _setApproval(context, ref, true),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 34),
                    foregroundColor: AppColors.emeraldDeep,
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              TextButton.icon(
                onPressed: onDetails,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 34),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Dossier'),
              ),
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 34),
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
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppColors.slateLight,
          ),
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
              color: color ?? AppColors.ink,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClientDossier extends StatelessWidget {
  const _ClientDossier({required this.row});

  final AdminClientPortfolio row;

  @override
  Widget build(BuildContext context) {
    final client = row.client;
    final summary = row.summary;

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(client.fullName)),
          StatusBadge(
            label: client.statusLabel,
            color: client.status == AccountStatus.active
                ? AppColors.emeraldDeep
                : AppColors.amber,
            wash: client.status == AccountStatus.active
                ? AppColors.emeraldWash
                : AppColors.amberWash,
            dense: true,
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              InfoRow(label: 'Email', value: client.email, labelWidth: 96),
              const Divider(height: 1),
              InfoRow(label: 'PAN', value: client.pan, labelWidth: 96, monospace: true),
              const Divider(height: 1),
              InfoRow(
                label: 'Phone',
                value: client.phone.isEmpty ? '—' : client.phone,
                labelWidth: 96,
              ),
              const Divider(height: 1),
              InfoRow(
                label: 'Client ID',
                value: client.clientId.isEmpty ? '—' : client.clientId,
                labelWidth: 96,
                monospace: true,
              ),
              const Divider(height: 1),
              InfoRow(
                label: 'Linked on',
                value: Formatters.date(client.linkedAt),
                labelWidth: 96,
              ),
              const Divider(height: 1),
              InfoRow(
                label: 'Last login',
                value: Formatters.timestamp(client.lastLoginAt),
                labelWidth: 96,
              ),
              const SizedBox(height: 16),
              const Text(
                'PORTFOLIO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 8),
              if (!row.hasPortfolio)
                const Text(
                  'No transactions imported for this PAN yet.',
                  style: TextStyle(fontSize: 12),
                )
              else ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        label: 'Current',
                        value: Formatters.currency(summary.currentValue),
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'Invested',
                        value: Formatters.currency(summary.totalInvested),
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'P&L',
                        value: Formatters.signedPercent(summary.returnPercent),
                        color: AppColors.forChange(summary.absolutePnl),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final holding in summary.holdings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            holding.schemeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                        ),
                        Text(
                          Formatters.currency(holding.currentValue),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
