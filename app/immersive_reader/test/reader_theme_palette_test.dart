import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/theme/reader_theme_palette.dart';

void main() {
  test('only highContrast reports isHighContrast', () {
    expect(ReaderThemePalette.warm.isHighContrast, isFalse);
    expect(ReaderThemePalette.sage.isHighContrast, isFalse);
    expect(ReaderThemePalette.ocean.isHighContrast, isFalse);
    expect(ReaderThemePalette.highContrast.isHighContrast, isTrue);
  });

  test('every palette has a human-readable, distinct label', () {
    final labels = ReaderThemePalette.values.map((p) => p.label).toSet();
    expect(labels.length, ReaderThemePalette.values.length);
    for (final label in labels) {
      expect(label, isNotEmpty);
    }
  });

  test('every palette defines a genuinely different light and dark background', () {
    for (final palette in ReaderThemePalette.values) {
      expect(palette.light.background, isNot(palette.dark.background));
    }
  });

  test('highContrast uses pure black/white, unlike the soft palettes', () {
    expect(ReaderThemePalette.highContrast.light.background.toARGB32(), 0xFFFFFFFF);
    expect(ReaderThemePalette.highContrast.light.text.toARGB32(), 0xFF000000);
    expect(ReaderThemePalette.highContrast.dark.background.toARGB32(), 0xFF000000);
    expect(ReaderThemePalette.highContrast.dark.text.toARGB32(), 0xFFFFFFFF);
  });

  test('each palette has its own bookmark highlight color, not one shared color', () {
    final highlights = ReaderThemePalette.values.map((p) => p.bookmarkHighlightColor).toSet();
    expect(highlights.length, ReaderThemePalette.values.length);
  });

  test('highContrast\'s bookmark highlight is more opaque than the soft palettes\' ', () {
    final highContrastAlpha = ReaderThemePalette.highContrast.bookmarkHighlightColor.a;
    for (final palette in [ReaderThemePalette.warm, ReaderThemePalette.sage, ReaderThemePalette.ocean]) {
      expect(highContrastAlpha, greaterThan(palette.bookmarkHighlightColor.a));
    }
  });
}
