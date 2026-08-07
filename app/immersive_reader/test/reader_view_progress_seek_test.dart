import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

// A tall document, matching the pattern in reader_view_navigation_test.dart,
// so there's enough scroll extent for a tap/drag on the progress bar to
// produce a visible percentage change.
DocumentModel _buildDocument({int paragraphCount = 200}) {
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
            tokens: List.generate(
              20,
              (j) => Token(tokenId: 't${i}_$j', text: 'word${i}_$j', isWord: true, positionIndex: i * 20 + j),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('tapping the middle of the progress bar seeks to that fraction', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    expect(find.text('0%'), findsOneWidget);

    await tester.tap(find.byType(LinearProgressIndicator));
    // The seek animates over 300ms.
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsNothing);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('tapping exactly at the start of the progress bar stays at 0%', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    // dx=0 gives a fraction of exactly 0.0 regardless of the bar's actual
    // rendered width, unlike a small-but-nonzero offset which can round up.
    final barTopLeft = tester.getTopLeft(find.byType(LinearProgressIndicator));
    await tester.tapAt(barTopLeft + const Offset(0, 4));
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('dragging along the progress bar scrubs the scroll position', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderView(document: _buildDocument(), controller: ReaderController()),
    ));
    await tester.pump();

    final bar = find.byType(LinearProgressIndicator);
    final barSize = tester.getSize(bar);

    // tester.drag() starts from the widget's center (50%) and moves right by
    // a large delta. Its internal touch-slop handling means the exact
    // resting fraction isn't pixel-precise (the precise tap-to-fraction
    // formula is already covered by the 50% tap test above), so this just
    // confirms a rightward drag moves well past the starting point.
    await tester.drag(bar, Offset(barSize.width * 0.4, 0));
    await tester.pumpAndSettle();

    final indicator = tester.widget<LinearProgressIndicator>(bar);
    expect(indicator.value, greaterThan(0.6));
  });
}
