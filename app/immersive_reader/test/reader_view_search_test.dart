import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';

// "target" appears once, in paragraph 0; "needle" appears in paragraphs 5
// and 150, far enough apart that jumping between them actually moves the
// scroll position - mirrors the tall-document pattern in
// reader_view_navigation_test.dart so the list is scrollable in the test
// viewport.
DocumentModel _buildDocument({int paragraphCount = 200}) {
  return DocumentModel(
    document_id: 'doc1',
    title: 'Test Document',
    paragraphs: List.generate(paragraphCount, (i) {
      final words = List.generate(20, (j) => 'word${i}_$j');
      if (i == 0) words[0] = 'target';
      // "open the door" spans three consecutive tokens - a multi-word query
      // must match across tokens, not within a single one.
      if (i == 0) {
        words[1] = 'open';
        words[2] = 'the';
        words[3] = 'door';
      }
      if (i == 5) words[3] = 'needle';
      if (i == 150) words[7] = 'needle';
      return ParagraphModel(
        paragraph_id: 'p$i',
        sentences: [
          SentenceModel(
            sentence_id: 's$i',
            tokens: List.generate(
              words.length,
              (j) => Token(tokenId: 't${i}_$j', text: words[j], isWord: true, positionIndex: i * 20 + j),
            ),
          ),
        ],
      );
    }),
  );
}

// A bare ReaderView as `home` has no Material ancestor for the search bar's
// TextField (unlike the real app, which hosts it inside HomePage's
// Scaffold - see main.dart) - wrapping in a Scaffold here matches real usage.
Future<void> _pumpReaderView(
  WidgetTester tester,
  DocumentModel document, {
  Map<String, String> replacements = const {},
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ReaderView(document: document, controller: ReaderController(), replacements: replacements),
    ),
  ));
  await tester.pump();
}

// Typing debounces (see _runSearch's Timer), and pumpAndSettle() alone
// doesn't reliably wait through a bare Timer that isn't itself driven by a
// scheduled frame - it can return before the debounce fires. Explicitly
// advancing the clock past the debounce window first, then settling the
// resulting async search + jump animation, is what actually waits for a
// search to complete.
Future<void> _typeSearchQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search bar is hidden until opened', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    expect(find.text('Search in document'), findsNothing);
  });

  testWidgets('tapping the search icon opens the search bar and focuses it', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();

    expect(find.text('Search in document'), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('Ctrl+F opens the search bar', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(find.text('Search in document'), findsOneWidget);
  });

  testWidgets('typing a query shows a match count and jumps to the first match', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();

    expect(find.text('0%'), findsOneWidget);

    await _typeSearchQuery(tester, 'needle');

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('a query with no matches shows "No results"', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();

    await _typeSearchQuery(tester, 'doesnotexist');

    expect(find.text('No results'), findsOneWidget);
  });

  testWidgets('next/previous cycle through matches and wrap around', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    await _typeSearchQuery(tester, 'needle');

    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next match'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Next match'));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous match'));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('closing the search bar clears the query and hides it', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    await _typeSearchQuery(tester, 'needle');

    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();

    expect(find.text('Search in document'), findsNothing);

    // Reopening should start from a clean slate, not the old query/matches.
    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsNothing);
    final reopenedField = tester.widget<TextField>(find.byType(TextField));
    expect(reopenedField.controller?.text, isEmpty);
  });

  testWidgets('Escape closes the search bar', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    expect(find.text('Search in document'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Search in document'), findsNothing);
  });

  testWidgets('a matched word is tappable/togglable like any other replaced token', (tester) async {
    // Sanity check that highlighting (a backgroundColor added to the token's
    // TextStyle) doesn't interfere with the existing tap-to-toggle/exposure
    // behaviour from ReplacementEngine - see _buildToken.
    await _pumpReaderView(tester, _buildDocument(), replacements: const {'t0_0': 'Ziel'});

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    await _typeSearchQuery(tester, 'target');

    expect(find.text('1/1'), findsOneWidget);
    expect(find.textContaining('Ziel'), findsOneWidget);
  });

  testWidgets('a multi-word query matches a phrase spanning several tokens', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    await _typeSearchQuery(tester, 'the door');

    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('No results'), findsNothing);
  });

  testWidgets('a multi-word query matching across a token boundary highlights both tokens', (tester) async {
    await _pumpReaderView(tester, _buildDocument());

    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    // Spans the tail of "open" and the head of "the" - only possible if
    // matching happens on the joined sentence text, not per-token.
    await _typeSearchQuery(tester, 'en the');

    expect(find.text('1/1'), findsOneWidget);
  });
}
