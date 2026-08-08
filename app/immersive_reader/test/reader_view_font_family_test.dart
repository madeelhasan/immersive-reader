import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';
import 'package:immersive_reader/theme/reader_font.dart';

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

void main() {
  testWidgets('reading content renders in the selected reader font', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderView(
          document: _buildDocument(),
          controller: ReaderController(),
          readerFont: ReaderFont.calibri,
        ),
      ),
    ));
    await tester.pump();

    final style = tester.widget<Text>(find.textContaining('hello')).style;
    expect(style?.fontFamily, 'Calibri');
  });

  testWidgets('defaults to Georgia when no font is specified', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    final style = tester.widget<Text>(find.textContaining('hello')).style;
    expect(style?.fontFamily, 'Georgia');
  });
}
