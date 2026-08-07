import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

DocumentModel _buildDocument({List<ChapterMarker> chapters = const [], int paragraphCount = 10}) {
  return DocumentModel(
    document_id: 'doc1',
    title: 'Test Document',
    paragraphs: List.generate(
      paragraphCount,
      (i) => ParagraphModel(
        paragraph_id: 'p$i',
        sentences: [
          SentenceModel(
            sentence_id: 's$i',
            // Several tokens per paragraph, repeated across many paragraphs,
            // so the list is tall enough to actually scroll in the test
            // viewport - a handful of one-word paragraphs wouldn't overflow.
            tokens: List.generate(
              20,
              (j) => Token(tokenId: 't${i}_$j', text: 'word${i}_$j', isWord: true, positionIndex: i * 20 + j),
            ),
          ),
        ],
      ),
    ),
    chapters: chapters,
  );
}

void main() {
  testWidgets('shows an inline progress bar starting at 0%', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('progress percentage updates as the reader scrolls', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(paragraphCount: 200), controller: ReaderController()),
    ));
    await tester.pump();

    expect(find.text('0%'), findsOneWidget);

    await tester.drag(find.byType(ScrollablePositionedList), const Offset(0, -5000));
    // ScrollablePositionedList computes item positions on a post-frame
    // callback (unlike a plain ScrollController, which updates pixels
    // synchronously as part of the drag), so a single pump() isn't always
    // enough to see the rebuilt percentage.
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsNothing);
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
