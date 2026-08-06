import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

DocumentModel _buildDocument({List<ChapterMarker> chapters = const []}) {
  return DocumentModel(
    document_id: 'doc1',
    title: 'Test Document',
    paragraphs: List.generate(
      10,
      (i) => ParagraphModel(
        paragraph_id: 'p$i',
        sentences: [
          SentenceModel(
            sentence_id: 's$i',
            tokens: [Token(tokenId: 't$i', text: 'word$i', isWord: true, positionIndex: i)],
          ),
        ],
      ),
    ),
    chapters: chapters,
  );
}

void main() {
  testWidgets('tapping the reading-progress button navigates to ReadingProgressView', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();

    expect(find.text('Test Document'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('Ctrl+G opens the go-to-page dialog', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(find.text('Go to page'), findsOneWidget);
    expect(find.text('Page 1-10'), findsOneWidget);
  });

  testWidgets('go-to-page dialog rejects out-of-range input and cancel closes it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '999');
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    // Out of range (max is 10) - dialog should still be open.
    expect(find.text('Go to page'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Go to page'), findsNothing);
  });
}
