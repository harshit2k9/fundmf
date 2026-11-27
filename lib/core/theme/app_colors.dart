import 'package:material_ui/material_ui.dart';

/// Fundmf's wealth-management palette.
///
/// The visual language is deliberately institutional: deep ink navy for
/// authority, a restrained gold for premium accents, ivory paper surfaces and
/// hairline borders. Gains and losses use a single muted green / brick pair so
/// colour always carries the same meaning across the app.
abstract final class AppColors {
  // ------------------------------------------------------------------ ink ---
  static const Color ink = Color(0xFF101C2E);
  static const Color inkDeep = Color(0xFF0A1421);
  static const Color inkSoft = Color(0xFF1D2E47);
  static const Color inkMuted = Color(0xFF55637A);

  /// Legacy aliases kept so every screen keeps compiling against one palette.
  static const Color navy = ink;
  static const Color navyDeep = inkDeep;
  static const Color navySoft = inkSoft;
  static const Color navyMuted = inkMuted;

  // ----------------------------------------------------------------- gold ---
  static const Color gold = Color(0xFFB0863F);
  static const Color goldDeep = Color(0xFF8A6528);
  static const Color goldSoft = Color(0xFFDCC29A);
  static const Color goldWash = Color(0xFFF7F1E6);

  // -------------------------------------------------------------- signals ---
  static const Color emerald = Color(0xFF1F7A5C);
  static const Color emeraldSoft = Color(0xFF6FBF9E);
  static const Color emeraldDeep = Color(0xFF17604A);
  static const Color emeraldWash = Color(0xFFEAF3EE);

  static const Color coral = Color(0xFFA8453C);
  static const Color coralSoft = Color(0xFFE08C82);
  static const Color coralDeep = Color(0xFF8A332B);
  static const Color coralWash = Color(0xFFFBEEEC);

  static const Color amber = Color(0xFFB4802A);
  static const Color amberWash = Color(0xFFFBF3E4);

  // ------------------------------------------------------------- neutrals ---
  static const Color slate = Color(0xFF6C7787);
  static const Color slateLight = Color(0xFF9AA4B2);
  static const Color border = Color(0xFFE5E3DD);
  static const Color borderStrong = Color(0xFFD3D0C7);
  static const Color canvas = Color(0xFFF5F4F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFAF9F6);

  /// Stable palette for allocation charts, legends and document highlights.
  static const List<Color> chartPalette = <Color>[
    Color(0xFF1D2E47),
    Color(0xFFB0863F),
    Color(0xFF3E7C7B),
    Color(0xFF5B7A9E),
    Color(0xFFA2654F),
    Color(0xFF6E5A7E),
    Color(0xFF8A8A4F),
    Color(0xFFC9A96A),
  ];

  /// Green for gains, brick for losses, slate for flat.
  static Color forChange(num value) {
    if (value > 0) return emeraldDeep;
    if (value < 0) return coralDeep;
    return slate;
  }

  static Color washForChange(num value) {
    if (value > 0) return emeraldWash;
    if (value < 0) return coralWash;
    return const Color(0xFFF1F2F4);
  }

  /// Hairline that matches the direction colour, used on statement rows.
  static Color borderForChange(num value) {
    if (value > 0) return const Color(0xFFCBE2D6);
    if (value < 0) return const Color(0xFFEFD2CD);
    return border;
  }
}
