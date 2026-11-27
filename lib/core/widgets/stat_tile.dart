import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import 'app_card.dart';

/// A single figure with its label — the building block of the overview and
/// admin dashboards.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.accent = AppColors.ink,
    this.wash = AppColors.surfaceMuted,
    this.compact = false,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color accent;
  final Color wash;

  /// Slightly tighter padding + smaller value, used inside cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(compact ? 12 : 14),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: AppColors.slate,
                    height: 1.3,
                  ),
                ),
              ),
              if (icon != null) ...<Widget>[
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: wash,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 12, color: accent),
                ),
              ],
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: compact ? 14 : 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: accent,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.slateLight,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
