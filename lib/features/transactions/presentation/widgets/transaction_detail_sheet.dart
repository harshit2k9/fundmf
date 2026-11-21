import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/transaction_model.dart';

/// Full CAMS audit trail for one transaction, presented as a bottom sheet.
class TransactionDetailSheet extends StatelessWidget {
  const TransactionDetailSheet({super.key, required this.transaction});

  final FundTransaction transaction;

  static Future<void> show(BuildContext context, FundTransaction transaction) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inflow = transaction.kind.isInflow;
    final accent = inflow ? AppColors.emeraldDeep : AppColors.coralDeep;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  StatusBadge(
                    label: transaction.kind.displayName.toUpperCase(),
                    color: accent,
                    wash: AppColors.washForChange(inflow ? 1 : -1),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.date(transaction.transactionDate),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                Formatters.currency(transaction.amount),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${inflow ? '+' : '−'}${Formatters.units(transaction.units)} units at NAV '
                '${Formatters.nav(transaction.purchaseNav)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    InfoRow(
                      label: 'Scheme',
                      value: transaction.schemeName,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Folio number',
                      value: transaction.folioNumber.isEmpty
                          ? '—'
                          : transaction.folioNumber,
                      monospace: true,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Transaction ID',
                      value: transaction.transactionId,
                      monospace: true,
                      trailing: IconButton(
                        tooltip: 'Copy transaction ID',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: transaction.transactionId),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Transaction ID copied'),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Date',
                      value: Formatters.date(transaction.transactionDate),
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Units',
                      value: Formatters.units(transaction.units),
                      monospace: true,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'NAV at purchase',
                      value: Formatters.nav(transaction.purchaseNav),
                      monospace: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'CAMS consolidated statements are parsed automatically. Contact '
                'the Fundmf admin if any figure looks incorrect.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.slateLight,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
