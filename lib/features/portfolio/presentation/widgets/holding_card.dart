import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/scheme_holding.dart';

/// One mutual fund scheme held by the investor.
///
/// The card leads with the scheme identity and return, then the three figures
/// that matter (invested, value, gain) and the position details on a hairline
/// footer.
class HoldingCard extends StatefulWidget {
  const HoldingCard({
    super.key,
    required this.holding,
    this.onTap,
  });

  final SchemeHolding holding;
  final VoidCallback? onTap;

  @override
  State<HoldingCard> createState() => _HoldingCardState();
}

class _HoldingCardState extends State<HoldingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    final pnlColor = AppColors.forChange(holding.pnl);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  Formatters.initials(holding.schemeName),
                  style: const TextStyle(
                    fontSize: 11.5,
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
                      holding.schemeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Folio ${holding.folioLabel}'
                      '${holding.schemeCode > 0 ? '  ·  AMFI ${holding.schemeCode}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _Metric(
                  label: 'Invested',
                  value: Formatters.currency(holding.investedAmount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Current value',
                  value: Formatters.currency(holding.currentValue),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  label: 'Gain / loss',
                  value: Formatters.signedCurrency(holding.pnl),
                  color: pnlColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (holding.allocationPercent / 100).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Text(
                    '${Formatters.percent(holding.allocationPercent)} of '
                    'portfolio',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.slate,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _expanded ? 'Hide details' : 'Details',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 10,
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
                _InlineStat(
                  label: 'CAGR',
                  value: Formatters.signedPercent(holding.cagrPercent),
                ),
              ],
            ),
            if (holding.navDate != null) ...<Widget>[
              const SizedBox(height: 7),
              Text(
                'NAV as of ${Formatters.date(holding.navDate)}  ·  '
                'Cost basis uses the average-cost method.',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.slateLight,
                  height: 1.4,
                ),
              ),
            ],
          ],
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
              fontSize: 12.5,
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
          '$label  ',
          style: const TextStyle(fontSize: 10.5, color: AppColors.slate),
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
