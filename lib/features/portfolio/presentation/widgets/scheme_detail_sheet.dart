import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/scheme_holding.dart';

/// Full position dossier for one scheme, opened from the holdings list.
class SchemeDetailSheet extends StatelessWidget {
  const SchemeDetailSheet({super.key, required this.holding});

  final SchemeHolding holding;

  static Future<void> show(BuildContext context, SchemeHolding holding) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchemeDetailSheet(holding: holding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forChange(holding.pnl);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  StatusBadge(
                    label: holding.navAvailable ? 'LIVE NAV' : 'AVG. COST',
                    color: holding.navAvailable
                        ? AppColors.emeraldDeep
                        : AppColors.slate,
                    wash: holding.navAvailable
                        ? AppColors.emeraldWash
                        : AppColors.surfaceMuted,
                  ),
                  const Spacer(),
                  Text(
                    holding.schemeCode > 0 ? 'AMFI ${holding.schemeCode}' : '',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.slate,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                holding.schemeName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CURRENT VALUE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.goldSoft.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.currency(holding.currentValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${Formatters.signedCurrency(holding.pnl)}  ·  '
                      '${Formatters.signedPercent(holding.pnlPercent)}  ·  '
                      'CAGR ${Formatters.signedPercent(holding.cagrPercent)}',
                      style: TextStyle(
                        color: holding.pnl >= 0
                            ? AppColors.emeraldSoft
                            : AppColors.coralSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: <Widget>[
                    InfoRow(
                      label: 'Units held',
                      value: Formatters.units(holding.units),
                      monospace: true,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Invested',
                      value: Formatters.currency(holding.investedAmount),
                      monospace: true,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Average NAV',
                      value: Formatters.nav(holding.averageNav),
                      monospace: true,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: holding.navAvailable ? 'Latest NAV' : 'NAV (cost)',
                      value: Formatters.nav(holding.currentNav),
                      monospace: true,
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'NAV date',
                      value: Formatters.date(holding.navDate),
                    ),
                    const Divider(height: 1),
                    InfoRow(
                      label: 'Portfolio share',
                      value: Formatters.percent(holding.allocationPercent),
                      valueColor: AppColors.goldDeep,
                    ),
                    const Divider(height: 1),
                    InfoRow(label: 'Folios', value: holding.folioLabel),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Returns use the average-cost method: redemptions reduce the '
                'cost basis at the running average NAV. ${color == AppColors.slate ? '' : 'Valuation follows the latest AMFI NAV published for this scheme.'}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.slateLight,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
