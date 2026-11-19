import 'package:material_ui/material_ui.dart';

/// Trust-first fintech palette. Navy carries authority, emerald and coral are
/// reserved for profit/loss signals so colour always means the same thing.
abstract final class AppColors {
  static const Color navy = Color(0xFF0B2447);
  static const Color navyDeep = Color(0xFF071A35);
  static const Color navySoft = Color(0xFF1B3A63);
  static const Color navyMuted = Color(0xFF4A6385);

  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF047857);
  static const Color emeraldWash = Color(0xFFE7F8F1);

  static const Color coral = Color(0xFFEF4444);
  static const Color coralDeep = Color(0xFFB91C1C);
  static const Color coralWash = Color(0xFFFDEDED);

  static const Color amber = Color(0xFFF59E0B);
  static const Color amberWash = Color(0xFFFEF6E7);

  static const Color slate = Color(0xFF64748B);
  static const Color slateLight = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color canvas = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);

  /// Stable palette for allocation charts and legends.
  static const List<Color> chartPalette = <Color>[
    Color(0xFF1B3A63),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  /// Green for gains, coral for losses, slate for flat.
  static Color forChange(num value) {
    if (value > 0) return emeraldDeep;
    if (value < 0) return coralDeep;
    return slate;
  }

  static Color washForChange(num value) {
    if (value > 0) return emeraldWash;
    if (value < 0) return coralWash;
    return const Color(0xFFF1F5F9);
  }
}
