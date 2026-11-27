import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/document_delivery.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/status_badge.dart';
import '../../reports/presentation/report_providers.dart';
import '../../users/domain/user_profile.dart';
import '../domain/client_portfolio.dart';
import 'admin_providers.dart';

/// Firm-level reporting: directory exports for the admin and on-demand client
/// statements for anything that needs to be sent by email or handed over.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String? _busy;
  String? _selectedEmail;

  Future<void> _export(
    String key,
    String label,
    Future<DeliveryResult> Function() task,
  ) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      final result = await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.delivered
                ? '$label is ready — choose where to save it.'
                : (result.message ?? '$label was saved to app storage.'),
          ),
          backgroundColor: result.delivered ? AppColors.ink : AppColors.amber,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${AppException.describe(error)}'),
          backgroundColor: AppColors.coralDeep,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(adminClientPortfoliosProvider);
    final exporter = ref.read(reportExporterProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: AsyncValueView<List<AdminClientPortfolio>>(
          asyncValue: rowsAsync,
          onRetry: () => ref.invalidate(adminClientPortfoliosProvider),
          builder: (rows) {
            final totals = AdminTotals.from(rows);
            if (_selectedEmail == null && rows.isNotEmpty) {
              _selectedEmail = rows.first.client.email;
            }
            final selected = rows
                .where((row) => row.client.email == _selectedEmail)
                .cast<AdminClientPortfolio?>()
                .firstWhere((row) => row != null, orElse: () => null);

            final reportRows = rows
                .map((row) => row.toReportRow())
                .toList(growable: false);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
              children: <Widget>[
                const Text(
                  'Firm reports',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Directory exports for internal review and client statements '
                  'for anything that has to leave the office.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                _TotalsGrid(totals: totals),
                const SizedBox(height: 18),
                const SectionHeader(
                  eyebrow: 'Directory',
                  title: 'Book of business export',
                  subtitle: 'Every client with their live valuation',
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.goldWash,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppColors.goldSoft),
                            ),
                            child: const Icon(
                              Icons.table_view_outlined,
                              size: 18,
                              color: AppColors.goldDeep,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${rows.length} clients  ·  '
                              '${Formatters.currency(totals.aum)} managed  ·  '
                              '${Formatters.signedPercent(totals.returnPercent)} return',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.slate,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: rows.isEmpty || _busy != null
                                  ? null
                                  : () => _export(
                                        'directory-csv',
                                        'Client directory',
                                        () => exporter.exportClientDirectoryCsv(
                                          rows: reportRows,
                                        ),
                                      ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                              ),
                              icon: _busy == 'directory-csv'
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded,
                                      size: 16),
                              label: const Text('CSV'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: rows.isEmpty || _busy != null
                                  ? null
                                  : () => _export(
                                        'directory-pdf',
                                        'Client directory',
                                        () => exporter.exportClientDirectoryPdf(
                                          rows: reportRows,
                                        ),
                                      ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 42),
                              ),
                              icon: _busy == 'directory-pdf'
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.picture_as_pdf_outlined,
                                      size: 16),
                              label: const Text('PDF'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SectionHeader(
                  eyebrow: 'Client statement',
                  title: 'Generate a portfolio statement',
                  subtitle: 'Same document the investor can download in the app',
                ),
                const SizedBox(height: 10),
                AppCard(
                  child: rows.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No clients yet',
                          message:
                              'Provision a client before generating a '
                              'statement.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            DropdownButtonFormField<String>(
                              initialValue: _selectedEmail,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Client',
                                prefixIcon:
                                    Icon(Icons.person_outline_rounded, size: 19),
                              ),
                              items: <DropdownMenuItem<String>>[
                                for (final row in rows)
                                  DropdownMenuItem<String>(
                                    value: row.client.email,
                                    child: Text(
                                      '${row.client.fullName}'
                                      '${row.client.clientId.isEmpty ? '' : '  ·  ${row.client.clientId}'}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedEmail = value),
                            ),
                            const SizedBox(height: 14),
                            if (selected != null) ...<Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _ClientLine(
                                      client: selected.client,
                                    ),
                                  ),
                                  StatusBadge(
                                    label: selected.hasPortfolio
                                        ? Formatters.currency(
                                            selected.summary.currentValue,
                                          )
                                        : 'No valuation',
                                    color: selected.hasPortfolio
                                        ? AppColors.ink
                                        : AppColors.slate,
                                    wash: AppColors.surfaceMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: !selected.hasPortfolio ||
                                        _busy != null
                                    ? null
                                    : () => _export(
                                          'statement',
                                          'Portfolio statement',
                                          () => exporter
                                              .exportPortfolioStatementPdf(
                                            summary: selected.summary,
                                            profile: selected.client,
                                          ),
                                        ),
                                icon: _busy == 'statement'
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.description_outlined,
                                        size: 16,
                                      ),
                                label: const Text('Generate statement PDF'),
                              ),
                              if (!selected.hasPortfolio) ...<Widget>[
                                const SizedBox(height: 6),
                                const Text(
                                  'This client has no imported transactions yet.',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.slateLight,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TotalsGrid extends StatelessWidget {
  const _TotalsGrid({required this.totals});

  final AdminTotals totals;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      StatTile(
        label: 'Assets managed',
        value: Formatters.currency(totals.aum),
        accent: AppColors.goldDeep,
        wash: AppColors.goldWash,
        compact: true,
      ),
      StatTile(
        label: 'Invested',
        value: Formatters.currency(totals.invested),
        compact: true,
      ),
      StatTile(
        label: 'Unrealised P&L',
        value: Formatters.signedCurrency(totals.pnl),
        accent: AppColors.forChange(totals.pnl),
        wash: AppColors.washForChange(totals.pnl),
        compact: true,
      ),
      StatTile(
        label: 'Clients',
        value: '${totals.clients}',
        caption: '${totals.active} active',
        compact: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _ClientLine extends StatelessWidget {
  const _ClientLine({required this.client});

  final UserProfile client;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          client.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
        ),
        const SizedBox(height: 2),
        Text(
          'PAN ${client.maskedPan}  ·  ${client.statusLabel}',
          style: const TextStyle(fontSize: 10, color: AppColors.slateLight),
        ),
      ],
    );
  }
}
