import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

// The reading column's width scales with the window between a 720px floor
// (the original fixed value, still the default at ordinary laptop widths -
// see reader_view.dart's _readableColumnWidth) and a 960px ceiling for very
// wide windows, so a wide monitor doesn't waste all its extra space as two
// large empty margins while a narrow one still gets its full width.
void main() {
  Future<double> renderedColumnWidth(WidgetTester tester, double windowWidth) async {
    tester.view.physicalSize = Size(windowWidth, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    return tester.getSize(find.byType(ScrollablePositionedList)).width;
  }

  testWidgets('stays at the 720px floor on a narrow window', (tester) async {
    final width = await renderedColumnWidth(tester, 800);
    expect(width, closeTo(720, 1));
  });

  testWidgets('matches the historical 720px default at a typical laptop width', (tester) async {
    final width = await renderedColumnWidth(tester, 1200); // 1200 * 0.6 == 720
    expect(width, closeTo(720, 1));
  });

  testWidgets('grows past 720px on a wider window', (tester) async {
    final width = await renderedColumnWidth(tester, 1500); // 1500 * 0.6 == 900
    expect(width, closeTo(900, 1));
  });

  testWidgets('caps at 960px even on a very wide (ultrawide) window', (tester) async {
    final width = await renderedColumnWidth(tester, 3000); // 3000 * 0.6 == 1800, clamped
    expect(width, closeTo(960, 1));
  });
}
