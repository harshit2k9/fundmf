import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/portfolio_summary.dart';

/// The dashboard's headline card: the portfolio value on ink, with the gain
/// and the supporting figures set in the same institutional type scale used by
/// the PDF statements.
class SummaryHeaderCard extends StatelessWidget {
  const SummaryHeaderCard({super.key, required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final isProfit = summary.isProfit;
    final accent = isProfit ? AppColors.emerald : AppColors.coralSoft;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.inkDeep, AppColors.ink, AppColors.inkSoft],
        ),
        border: Border.all(color: AppColors.inkSoft),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'TOTAL PORTFOLIO VALUE',
                  style: TextStyle(
                    color: AppColors.goldSoft.withValues(alpha: 0.95),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      summary.hasLiveNav
                          ? Icons.bolt_rounded
                          : Icons.history_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      summary.hasLiveNav ? 'LIVE NAV' : 'AVG. COST',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.currency(summary.currentValue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.4,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                isProfit
                    ? Icons.arrow_outward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: accent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${Formatters.signedCurrency(summary.absolutePnl)}  '
                  '(${Formatters.signedPercent(summary.returnPercent)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'unrealised',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryStat(
                  label: 'Invested',
                  value: Formatters.currency(summary.totalInvested),
                ),
              ),
              _divider(),
              Expanded(
                child: _SummaryStat(
                  label: 'CAGR',
                  value: Formatters.signedPercent(summary.cagrPercent),
                ),
              ),
              _divider(),
              Expanded(
                child: _SummaryStat(
                  label: 'Schemes',
                  value: '${summary.holdings.length}'.padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.1),
      );
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
