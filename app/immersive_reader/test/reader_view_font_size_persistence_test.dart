import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

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

Future<void> _pumpReader(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
  ));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('adjusting font size persists it to SharedPreferences', (tester) async {
    await _pumpReader(tester);

    await tester.tap(find.byTooltip('Increase font size'));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('font_size'), 18.0);
  });

  testWidgets('a new ReaderView restores a previously saved font size', (tester) async {
    SharedPreferences.setMockInitialValues({'font_size': 24.0});

    await _pumpReader(tester);
    await tester.pump();

    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('with nothing saved, font size defaults to 16', (tester) async {
    await _pumpReader(tester);

    expect(find.text('16'), findsOneWidget);
  });
}
