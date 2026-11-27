import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

/// The base surface used across Fundmf: white paper, a hairline border and a
/// 16px radius. Pass [gradient] for the ink summary card, [onTap] to make it
/// interactive, or [emphasis] to lift a card above the canvas.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.gradient,
    this.onTap,
    this.emphasis = false,
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  /// Adds a soft shadow so the card reads as the primary surface.
  final bool emphasis;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final isGradient = gradient != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: isGradient ? null : (color ?? AppColors.surface),
        gradient: gradient,
        border: isGradient
            ? null
            : Border.all(color: borderColor ?? AppColors.border),
        boxShadow: emphasis
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          splashColor: AppColors.ink.withValues(alpha: 0.03),
          highlightColor: AppColors.ink.withValues(alpha: 0.02),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
