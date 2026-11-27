import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// Regulatory disclaimer shown as the app footer on every shell.
class RiskDisclaimer extends StatelessWidget {
  const RiskDisclaimer({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  static const String text =
      'Mutual Funds are subject to market risk. Read all scheme related '
      'documents carefully before investing.';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: AppColors.slateLight,
          height: 1.5,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
