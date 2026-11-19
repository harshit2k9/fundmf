import 'dart:ui' show FontFeature;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/scheme_holding.dart';

/// One mutual fund scheme held by the investor.
class HoldingCard extends StatelessWidget {
  const HoldingCard({super.key, required this.holding});

  final SchemeHolding holding;

  @override
  Widget build(BuildContext context) {
    final pnlColor = AppColors.forChange(holding.pnl);

    return AppCard(
      padding: const EdgeInsets.all(18),
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
                  color: AppColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  Formatters.initials(holding.schemeName),
                  style: const TextStyle(
                    fontSize: 12.5,
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
                      holding.schemeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Folio ${holding.folioLabel}'
                      '${holding.schemeCode > 0 ? '  ·  AMFI ${holding.schemeCode}' : ''}',
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
              StatusBadge(
                label: Formatters.signedPercent(holding.pnlPercent),
                color: pnlColor,
                wash: AppColors.washForChange(holding.pnl),
                icon: holding.pnl >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: 'Invested',
                  value: Formatters.currency(holding.investedAmount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: 'Current value',
                  value: Formatters.currency(holding.currentValue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: 'P&L',
                  value: Formatters.signedCurrency(holding.pnl),
                  color: pnlColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: <Widget>[
              _InlineStat(
                label: 'Units',
                value: Formatters.units(holding.units),
              ),
              _InlineStat(
                label: 'Avg. NAV',
                value: Formatters.nav(holding.averageNav),
              ),
              _InlineStat(
                label: holding.navAvailable ? 'Live NAV' : 'NAV (cost)',
                value: Formatters.nav(holding.currentNav),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value:
                  (holding.allocationPercent / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              backgroundColor: AppColors.canvas,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${Formatters.percent(holding.allocationPercent)} of portfolio'
            '${holding.navAvailable && holding.navDate != null ? '  ·  NAV as of ${Formatters.date(holding.navDate)}' : ''}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.slateLight),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

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
          style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
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
              color: color ?? AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label ',
          style: const TextStyle(fontSize: 11, color: AppColors.slate),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
