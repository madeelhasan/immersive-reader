import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

void main() {
  testWidgets('tapping a replaced word toggles it between German and English', (tester) async {
    final token = Token(tokenId: 't1', text: 'house', isWord: true, positionIndex: 0);
    final document = DocumentModel(
      document_id: 'doc1',
      title: 'Test',
      paragraphs: [
        ParagraphModel(
          paragraph_id: 'p1',
          sentences: [
            SentenceModel(sentence_id: 's1', tokens: [token]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ReaderView(
        document: document,
        controller: ReaderController(),
        replacements: const {'t1': 'Haus'},
      ),
    ));
    await tester.pump();

    expect(find.text('Haus '), findsOneWidget);
    expect(find.text('house '), findsNothing);

    await tester.tap(find.text('Haus '));
    await tester.pump();

    expect(find.text('house '), findsOneWidget);
    expect(find.text('Haus '), findsNothing);

    await tester.tap(find.text('house '));
    await tester.pump();

    expect(find.text('Haus '), findsOneWidget);
  });

  testWidgets('words with no replacement are never tappable-styled', (tester) async {
    final token = Token(tokenId: 't1', text: 'bicycle', isWord: true, positionIndex: 0);
    final document = DocumentModel(
      document_id: 'doc1',
      title: 'Test',
      paragraphs: [
        ParagraphModel(
          paragraph_id: 'p1',
          sentences: [
            SentenceModel(sentence_id: 's1', tokens: [token]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ReaderView(
        document: document,
        controller: ReaderController(),
      ),
    ));
    await tester.pump();

    expect(find.text('bicycle '), findsOneWidget);
  });
}
