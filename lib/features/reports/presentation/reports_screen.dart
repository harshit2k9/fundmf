import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/document_delivery.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_providers.dart';
import '../../portfolio/domain/portfolio_summary.dart';
import '../../portfolio/presentation/portfolio_providers.dart';
import '../../transactions/domain/transaction_model.dart';
import '../../users/domain/user_profile.dart';
import 'report_providers.dart';

/// Export centre. Every document the investor can take to a CA, a bank or an
/// adviser lives here, generated from the same figures the app shows.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _busy;

  Future<void> _run(
    String key,
    String label,
    Future<DeliveryResult> Function() task,
  ) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      final result = await task();
      if (!mounted) return;
      final message = result.delivered
          ? '$label saved.'
          : (result.message ?? '$label was saved to app storage.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
    final profile = ref.watch(activeProfileProvider);
    final summaryAsync = ref.watch(portfolioSummaryProvider);
    final transactions =
        ref.watch(transactionFeedProvider).value ?? const <FundTransaction>[];

    if (profile == null) {
      return const Center(child: Text('Profile unavailable'));
    }

    final summary = summaryAsync.value ?? PortfolioSummary.empty;
    final exporter = ref.read(reportExporterProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Reports & statements',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Generate the same verified figures you see in the app as a '
                  'PDF statement or a spreadsheet. Exports download on web and '
                  'open your device\u2019s save dialog on mobile, so you choose '
                  'the folder.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _ClientBanner(profile: profile, summary: summary),
                const SizedBox(height: 18),
                const SectionHeader(
                  eyebrow: 'Documents',
                  title: 'Available exports',
                  subtitle: 'Generated on demand from your CAMS ledger',
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  icon: Icons.description_outlined,
                  title: 'Portfolio statement',
                  description:
                      'Valuation, invested amount, absolute and annualised '
                      'returns, and every scheme with units, NAVs and gains.',
                  meta: summary.isEmpty
                      ? 'Needs at least one holding'
                      : '${summary.holdings.length} schemes  ·  PDF',
                  badge: 'PDF',
                  enabled: !summary.isEmpty,
                  busy: _busy == 'statement',
                  onPressed: () => _run(
                    'statement',
                    'Portfolio statement',
                    () => exporter.exportPortfolioStatementPdf(
                      summary: summary,
                      profile: profile,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  icon: Icons.table_chart_outlined,
                  title: 'Holdings schedule',
                  description:
                      'A spreadsheet row per scheme with folio, AMFI code, '
                      'units, average NAV, current NAV, P&L and allocation.',
                  meta: summary.isEmpty
                      ? 'Needs at least one holding'
                      : '${summary.holdings.length} rows  ·  CSV',
                  badge: 'CSV',
                  enabled: !summary.isEmpty,
                  busy: _busy == 'holdings',
                  onPressed: () => _run(
                    'holdings',
                    'Holdings schedule',
                    () => exporter.exportHoldingsCsv(
                      summary: summary,
                      profile: profile,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _DocumentTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaction ledger',
                  description:
                      'Every CAMS transaction with date, scheme, folio, type, '
                      'units, NAV and amount — the complete audit trail.',
                  meta: transactions.isEmpty
                      ? 'No transactions imported yet'
                      : '${transactions.length} transactions  ·  PDF or CSV',
                  badge: 'PDF / CSV',
                  enabled: transactions.isNotEmpty,
                  busy: _busy == 'ledger-pdf' || _busy == 'ledger-csv',
                  onPressed: () => _run(
                    'ledger-pdf',
                    'Transaction ledger',
                    () => exporter.exportTransactionLedgerPdf(
                      transactions: transactions,
                      profile: profile,
                    ),
                  ),
                  secondaryLabel: 'CSV',
                  secondaryBusy: _busy == 'ledger-csv',
                  onSecondary: () => _run(
                    'ledger-csv',
                    'Transaction ledger',
                    () => exporter.exportTransactionLedgerCsv(
                      transactions: transactions,
                      profile: profile,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppCard(
                  color: AppColors.surfaceMuted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.gavel_rounded,
                            size: 15,
                            color: AppColors.slate,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'SOURCE & DISCLAIMER',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.slate.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Figures are derived from consolidated CAMS and KFintech '
                        'account statements and valued at the latest AMFI NAV. '
                        'Cost basis follows the average-cost method. These '
                        'documents are informational and are not tax statements '
                        'or investment advice. Mutual fund investments are '
                        'subject to market risk.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.slate,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Generated ${Formatters.timestamp(DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slateLight,
                        ),
                      ),
                    ],
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

class _ClientBanner extends StatelessWidget {
  const _ClientBanner({required this.profile, required this.summary});

  final UserProfile profile;
  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  profile.initials,
                  style: const TextStyle(
                    color: AppColors.goldSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client ${profile.clientId.isEmpty ? '—' : profile.clientId}'
                      '  ·  PAN ${Formatters.maskPan(profile.pan)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.slate,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: 'VERIFIED',
                color: AppColors.emeraldDeep,
                wash: AppColors.emeraldWash,
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          if (!summary.isEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _BannerStat(
                    label: 'Portfolio value',
                    value: Formatters.currency(summary.currentValue),
                  ),
                ),
                Expanded(
                  child: _BannerStat(
                    label: 'Invested',
                    value: Formatters.currency(summary.totalInvested),
                  ),
                ),
                Expanded(
                  child: _BannerStat(
                    label: 'Unrealised P&L',
                    value: Formatters.signedPercent(summary.returnPercent),
                    color: AppColors.forChange(summary.absolutePnl),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value, this.color});

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
              fontSize: 12,
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

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.meta,
    required this.badge,
    required this.enabled,
    required this.busy,
    required this.onPressed,
    this.secondaryLabel,
    this.secondaryBusy = false,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String description;
  final String meta;
  final String badge;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;
  final String? secondaryLabel;
  final bool secondaryBusy;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Icon(icon, size: 18, color: AppColors.goldDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: badge,
                          color: AppColors.slate,
                          wash: AppColors.surfaceMuted,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.slate,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.slateLight,
                  ),
                ),
              ),
              if (secondaryLabel != null) ...<Widget>[
                OutlinedButton(
                  onPressed: enabled && !busy && !secondaryBusy
                      ? onSecondary
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: secondaryBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(secondaryLabel!),
                ),
                const SizedBox(width: 8),
              ],
              FilledButton.icon(
                onPressed: enabled && !busy && !secondaryBusy
                    ? onPressed
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(busy ? 'Preparing…' : 'Export'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
