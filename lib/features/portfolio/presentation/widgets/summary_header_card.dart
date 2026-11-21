import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/portfolio_summary.dart';

/// The dashboard's headline card. Navy gradient keeps the numbers dominant;
/// the P&L pill is the only place green/red appears here.
class SummaryHeaderCard extends StatelessWidget {
  const SummaryHeaderCard({super.key, required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final isProfit = summary.isProfit;
    final accent = isProfit ? AppColors.emerald : AppColors.coral;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.navyDeep, AppColors.navy, AppColors.navySoft],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'CURRENT PORTFOLIO VALUE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      summary.hasLiveNav
                          ? Icons.bolt_rounded
                          : Icons.history_rounded,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      summary.hasLiveNav ? 'Live NAV' : 'Avg. cost',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
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
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isProfit
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 13,
                      color: accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${Formatters.signedCurrency(summary.absolutePnl)}  ·  '
                      '${Formatters.signedPercent(summary.returnPercent)}  ·  '
                      'CAGR ${Formatters.signedPercent(summary.cagrPercent)}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'net P&L',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _SummaryStat(
                  label: 'Invested',
                  value: Formatters.currency(summary.totalInvested),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SummaryStat(
                  label: 'Schemes held',
                  value: summary.holdings.length.toString().padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
