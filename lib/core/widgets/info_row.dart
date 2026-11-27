import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Label on the left, value on the right — used by the profile screen, the
/// transaction audit sheet and the admin client dossier.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.monospace = false,
    this.labelWidth = 132,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final bool monospace;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: valueColor ?? AppColors.ink,
                letterSpacing: monospace ? 0.3 : 0,
                fontFeatures: monospace
                    ? const <FontFeature>[FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}
