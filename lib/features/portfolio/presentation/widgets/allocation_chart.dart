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
    final width = MediaQuery.sizeOf(context).width;
    final chartSize = width < 380 ? 176.0 : 196.0;
    final selectedIndex =
        (_selectedIndex >= 0 && _selectedIndex < holdings.length)
            ? _selectedIndex
            : -1;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            eyebrow: 'Composition',
            title: 'Portfolio allocation',
            subtitle: 'Share of current value',
            trailing: holdings.isEmpty
                ? null
                : Text(
                    Formatters.currency(total),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (holdings.isEmpty)
            const EmptyState(
              icon: Icons.donut_large_rounded,
              title: 'No allocation yet',
              message:
                  'Your CAMS statements populate this chart as soon as '
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
                        centerSpaceRadius: chartSize * 0.31,
                        sectionsSpace: 2,
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
                              radius: selectedIndex == i ? 22 : 17,
                              showTitle: holdings.length <= 6,
                              title:
                                  '${holdings[i].allocationPercent.toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
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
                                  holdings[selectedIndex].currentValue)
                              : Formatters.compactCurrency(total),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          width: chartSize * 0.54,
                          child: Text(
                            selectedIndex >= 0
                                ? holdings[selectedIndex].shortName
                                : '${holdings.length} schemes',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
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
            const SizedBox(height: 18),
            ...List<Widget>.generate(holdings.length, (index) {
              final holding = holdings[index];
              final selected = selectedIndex == index;
              return Material(
                color: selected ? AppColors.surfaceMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(
                    () => _selectedIndex = selected ? -1 : index,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 7,
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _colorAt(index),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            holding.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.percent(holding.allocationPercent),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
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
