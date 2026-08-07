import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

// Regression coverage for a real reported hang: on a document with
// thousands of paragraphs, jumping far from the current scroll position
// (via go-to-page, search, chapters, or bookmarks) used to take 11-14+
// seconds - a genuine freeze, not just sluggishness. Root cause: a plain
// ListView.builder's SliverList has to synchronously build/measure a large
// span of off-screen content to resolve a jump to a position far from
// whatever's currently realized; that cost is roughly proportional to how
// far the jump is, not to how the target was computed, so neither
// instant-vs-animated jumps nor retrying/refining the target fixed it.
// The real fix was switching to scrollable_positioned_list, whose
// index-based ItemScrollController.jumpTo() doesn't have that cost -
// verified here at the reported scale (9000 paragraphs) with a hard time
// budget, not just "does it eventually finish".
DocumentModel _buildHugeDocument({int paragraphCount = 9000, int wordsPerParagraph = 12}) {
  return DocumentModel(
    document_id: 'huge',
    title: 'Huge Test Document',
    paragraphs: List.generate(paragraphCount, (i) {
      final words = List.generate(wordsPerParagraph, (j) => 'word${i}_$j');
      if (i == paragraphCount - 5) {
        words[2] = 'open';
        words[3] = 'the';
        words[4] = 'door';
      }
      return ParagraphModel(
        paragraph_id: 'p$i',
        sentences: [
          SentenceModel(
            sentence_id: 's$i',
            tokens: List.generate(
              words.length,
              (j) => Token(tokenId: 't${i}_$j', text: words[j], isWord: true, positionIndex: i * words.length + j),
            ),
          ),
        ],
      );
    }),
  );
}

void main() {
  testWidgets('a far go-to-page jump on a 9000-paragraph document stays well under a second', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildHugeDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '8995');

    final sw = Stopwatch()..start();
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    sw.stop();

    // A generous ceiling, not a tight perf assertion - this exists to catch
    // a regression back to multi-second territory, not to chase milliseconds.
    expect(sw.elapsedMilliseconds, lessThan(2000));
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a phrase search + jump on a 9000-paragraph document stays well under a few seconds', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildHugeDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();

    final sw = Stopwatch()..start();
    await tester.enterText(find.byType(TextField), 'the door');
    await tester.pump(const Duration(milliseconds: 500)); // clears the search debounce
    await tester.pumpAndSettle();
    sw.stop();

    expect(find.text('1/1'), findsOneWidget);
    expect(sw.elapsedMilliseconds, lessThan(3000));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
