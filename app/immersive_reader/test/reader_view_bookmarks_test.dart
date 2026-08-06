import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

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

Future<void> _openBookmarksList(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.bookmarks_outlined));
  await tester.pumpAndSettle();
}

Future<void> _closeBottomSheet(WidgetTester tester) async {
  await tester.tap(find.byType(ModalBarrier).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding a bookmark shows it in the bookmarks list', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();

    await _openBookmarksList(tester);

    expect(find.text('0% through'), findsOneWidget);
    expect(find.text('No bookmarks yet'), findsNothing);
  });

  testWidgets('auto-replace off keeps multiple independent bookmarks', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();

    await _openBookmarksList(tester);

    // Two distinct rows, neither flagged as the auto-advancing one.
    expect(find.byIcon(Icons.bookmark_border), findsNWidgets(2));
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('auto-replace on moves the current-position bookmark and offers Undo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    // Turn auto-replace on via the switch inside the bookmarks sheet.
    await _openBookmarksList(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await _closeBottomSheet(tester);

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump(); // let the SnackBar appear

    expect(find.textContaining('Bookmark moved to'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await _openBookmarksList(tester);
    // Only one bookmark survives - the current-position one, moved forward.
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    expect(find.text('0% through'), findsNothing);
    await _closeBottomSheet(tester);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    await _openBookmarksList(tester);
    expect(find.text('0% through'), findsOneWidget);
  });

  testWidgets('deleting a bookmark removes it from the list', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ReaderView(document: _buildDocument(), controller: ReaderController())),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
    await tester.pump();
    await _openBookmarksList(tester);

    expect(find.text('0% through'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('No bookmarks yet'), findsOneWidget);
  });
}
