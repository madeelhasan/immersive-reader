import 'package:flutter/material.dart';

/// The colors a [ReaderThemePalette] resolves to at one brightness.
class PaletteColors {
  final Color background;
  final Color text;
  final Color accent;

  const PaletteColors({required this.background, required this.text, required this.accent});
}

/// A named color palette the reader can pick in Settings, independent of
/// the existing light/dark/system ThemeMode toggle - ThemeMode controls
/// brightness, this controls which set of colors is used at that
/// brightness. [warm] is the original (only) palette this app shipped
/// with; [sage]/[ocean] are additional soft options; [highContrast] is a
/// dedicated accessibility theme, not just "another soft option" - see
/// [isHighContrast], which ReaderView uses to also raise the minimum font
/// size and bold reading text, not just swap colors.
enum ReaderThemePalette {
  warm('Warm'),
  sage('Sage'),
  ocean('Ocean'),
  highContrast('High Contrast');

  const ReaderThemePalette(this.label);
  final String label;

  bool get isHighContrast => this == ReaderThemePalette.highContrast;

  PaletteColors get light => switch (this) {
        warm => const PaletteColors(
            background: Color(0xFFFBF6EC),
            text: Color(0xFF2B2620),
            accent: Color(0xFF8B5E34),
          ),
        sage => const PaletteColors(
            background: Color(0xFFF4F7F2),
            text: Color(0xFF24312A),
            accent: Color(0xFF6B8F71),
          ),
        ocean => const PaletteColors(
            background: Color(0xFFF2F6FA),
            text: Color(0xFF22303D),
            accent: Color(0xFF4C7A9E),
          ),
        highContrast => const PaletteColors(
            background: Color(0xFFFFFFFF),
            text: Color(0xFF000000),
            accent: Color(0xFF0D47A1),
          ),
      };

  PaletteColors get dark => switch (this) {
        warm => const PaletteColors(
            background: Color(0xFF1E1B16),
            text: Color(0xFFEDE6D9),
            accent: Color(0xFFD9A566),
          ),
        sage => const PaletteColors(
            background: Color(0xFF1B211D),
            text: Color(0xFFE3EAE2),
            accent: Color(0xFF9BBFA0),
          ),
        ocean => const PaletteColors(
            background: Color(0xFF161E27),
            text: Color(0xFFE2ECF4),
            accent: Color(0xFF7FB2D9),
          ),
        highContrast => const PaletteColors(
            background: Color(0xFF000000),
            text: Color(0xFFFFFFFF),
            accent: Color(0xFFFFD600),
          ),
      };

  /// The bookmark-jump "you are here" flash color (ReaderView) - a fixed,
  /// deliberately chosen color per palette rather than one color for every
  /// theme, since a single hue can't be guaranteed to contrast well against
  /// every palette's background/text. This is exactly the bug that made
  /// the original flash invisible against the warm theme: it used
  /// colorScheme.primaryContainer, a color derived from (and therefore
  /// close to) the theme's own background. highContrast uses a near-opaque
  /// fill rather than a translucent wash - a subtle tint would defeat the
  /// point of a high-contrast theme.
  Color get bookmarkHighlightColor => switch (this) {
        warm => Colors.amber.withValues(alpha: 0.55),
        sage => const Color(0xFFFF8A65).withValues(alpha: 0.55),
        ocean => const Color(0xFFFFCA28).withValues(alpha: 0.55),
        highContrast => const Color(0xFFFFEB3B).withValues(alpha: 0.85),
      };
}
