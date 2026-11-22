import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Regulatory disclaimer shown as the app footer.
class RiskDisclaimer extends StatelessWidget {
  const RiskDisclaimer({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  static const String text =
      'Mutual Funds are subject to market risk. Invest wisely';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          color: AppColors.slateLight,
          height: 1.5,
        ),
      ),
    );
  }
}
