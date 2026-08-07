import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';
import 'package:immersive_reader/theme/reader_theme_palette.dart';

DocumentModel _buildDocument() {
  return DocumentModel(
    document_id: 'doc1',
    title: 'Test Document',
    paragraphs: [
      ParagraphModel(
        paragraph_id: 'p0',
        sentences: [
          SentenceModel(
            sentence_id: 's0',
            tokens: [Token(tokenId: 't0', text: 'hello', isWord: true, positionIndex: 0)],
          ),
        ],
      ),
    ],
  );
}

Future<void> _pumpReader(WidgetTester tester, {required ReaderThemePalette themePalette}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ReaderView(document: _buildDocument(), controller: ReaderController(), themePalette: themePalette),
    ),
  ));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('highContrast raises the displayed/minimum font size above the default 16', (tester) async {
    await _pumpReader(tester, themePalette: ReaderThemePalette.highContrast);

    // Default persisted font size (16) is below the 20px high-contrast
    // floor - the displayed size should reflect the floor, not 16.
    expect(find.text('20'), findsOneWidget);
    expect(find.text('16'), findsNothing);
  });

  testWidgets('the decrease-font-size button is disabled at the highContrast floor', (tester) async {
    await _pumpReader(tester, themePalette: ReaderThemePalette.highContrast);

    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));
    expect(button.onPressed, isNull);
  });

  testWidgets('a non-highContrast palette keeps the normal 16px default and 10px floor', (tester) async {
    await _pumpReader(tester, themePalette: ReaderThemePalette.warm);

    expect(find.text('16'), findsOneWidget);
    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('reading text is bold under highContrast, not under other palettes', (tester) async {
    await _pumpReader(tester, themePalette: ReaderThemePalette.highContrast);
    final highContrastStyle = tester.widget<Text>(find.textContaining('hello')).style;
    expect(highContrastStyle?.fontWeight, FontWeight.bold);

    await _pumpReader(tester, themePalette: ReaderThemePalette.warm);
    final warmStyle = tester.widget<Text>(find.textContaining('hello')).style;
    expect(warmStyle?.fontWeight, isNot(FontWeight.bold));
  });
}
