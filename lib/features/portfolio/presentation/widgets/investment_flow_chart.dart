import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/portfolio_analytics.dart';

/// Twelve-month bar chart of net money added to the portfolio.
///
/// Bars are ink; the current month is gold. Tap a bar to read its exact value
/// in the strip above the chart.
class InvestmentFlowChart extends StatefulWidget {
  const InvestmentFlowChart({
    super.key,
    required this.flows,
    this.height = 168,
  });

  final List<MonthlyFlow> flows;
  final double height;

  @override
  State<InvestmentFlowChart> createState() => _InvestmentFlowChartState();
}

class _InvestmentFlowChartState extends State<InvestmentFlowChart> {
  int? _touched;

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.flows.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No investment activity in the last 12 months',
            style: TextStyle(fontSize: 12, color: AppColors.slate),
          ),
        ),
      );
    }

    final flows = widget.flows;
    final maxValue = flows
        .map((flow) => flow.net.abs())
        .fold<double>(0, (max, value) => value > max ? value : max);
    final maxY = maxValue <= 0 ? 1000.0 : maxValue * 1.25;
    final touched = _touched != null && _touched! < flows.length
        ? flows[_touched!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                touched == null
                    ? 'Net invested per month'
                    : '${_months[touched.month.month - 1]} ${touched.month.year}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.slate,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              Formatters.currency(
                touched == null
                    ? flows.fold<double>(0, (sum, flow) => sum + flow.net)
                    : touched.net,
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: widget.height,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) {
                    setState(() => _touched = null);
                    return;
                  }
                  setState(() {
                    _touched = response?.spot?.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.ink,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final flow = flows[group.x];
                    return BarTooltipItem(
                      '${_months[flow.month.month - 1]} ${flow.month.year}\n',
                      const TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: Formatters.currency(flow.net),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 1,
                  dashArray: <int>[3, 3],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= flows.length) {
                        return const SizedBox.shrink();
                      }
                      // Every other month keeps the axis readable on phones.
                      if (flows.length > 6 && index.isOdd) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _months[flows[index].month.month - 1],
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.slateLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: <BarChartGroupData>[
                for (var index = 0; index < flows.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: flows[index].net.abs(),
                        width: flows.length > 8 ? 12 : 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                        color: _touched == index
                            ? AppColors.gold
                            : (index == flows.length - 1
                                ? AppColors.goldDeep
                                : AppColors.inkSoft),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.surfaceMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
