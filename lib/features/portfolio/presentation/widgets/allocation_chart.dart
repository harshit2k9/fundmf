import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/scheme_holding.dart';

/// Donut chart of allocation by current value. Tapping a slice (or its legend
/// row) reveals that scheme's value in the middle of the ring.
class AllocationChartCard extends StatefulWidget {
  const AllocationChartCard({super.key, required this.holdings});

  final List<SchemeHolding> holdings;

  @override
  State<AllocationChartCard> createState() => _AllocationChartCardState();
}

class _AllocationChartCardState extends State<AllocationChartCard> {
  int _selectedIndex = -1;

  Color _colorAt(int index) =>
      AppColors.chartPalette[index % AppColors.chartPalette.length];

  @override
  Widget build(BuildContext context) {
    final holdings = widget.holdings;
    final total = holdings.fold<double>(0, (sum, h) => sum + h.currentValue);
    final dimensions = MediaQuery.sizeOf(context).width;
    final chartSize = dimensions < 380 ? 190.0 : 210.0;
    // A refresh can shrink the holdings list; never index past the end.
    final selectedIndex =
        (_selectedIndex >= 0 && _selectedIndex < holdings.length)
            ? _selectedIndex
            : -1;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            title: 'Portfolio allocation',
            subtitle: 'Share of current value',
          ),
          const SizedBox(height: 18),
          if (holdings.isEmpty)
            const EmptyState(
              icon: Icons.donut_large_rounded,
              title: 'No allocation yet',
              message:
                  'Your CAMS statements will populate this chart as soon as '
                  'transactions are synced.',
            )
          else ...<Widget>[
            Center(
              child: SizedBox(
                width: chartSize,
                height: chartSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: chartSize * 0.3,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions) return;
                            final index =
                                response?.touchedSection?.touchedSectionIndex ??
                                    -1;
                            setState(() {
                              _selectedIndex =
                                  (index >= 0 && index < holdings.length)
                                      ? index
                                      : -1;
                            });
                          },
                        ),
                        sections: <PieChartSectionData>[
                          for (var i = 0; i < holdings.length; i++)
                            PieChartSectionData(
                              value: holdings[i].currentValue <= 0
                                  ? 0.0001
                                  : holdings[i].currentValue,
                              color: _colorAt(i),
                              radius: selectedIndex == i ? 24 : 18,
                              showTitle: holdings.length <= 6,
                              title:
                                  '${holdings[i].allocationPercent.toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                              borderSide: BorderSide.none,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          selectedIndex >= 0
                              ? Formatters.compactCurrency(
                                  holdings[selectedIndex].currentValue,
                                )
                              : Formatters.compactCurrency(total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: chartSize * 0.52,
                          child: Text(
                            selectedIndex >= 0
                                ? holdings[selectedIndex].shortName
                                : '${holdings.length} schemes',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.slate,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            ...List<Widget>.generate(holdings.length, (index) {
              final holding = holdings[index];
              final selected = selectedIndex == index;
              return Material(
                color: selected ? AppColors.canvas : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(
                    () => _selectedIndex = selected ? -1 : index,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _colorAt(index),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            holding.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.percent(holding.allocationPercent),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
