import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';
import 'package:immersive_reader/tts/tts_service.dart';

/// Overrides every method so no test ever touches flutter_tts's real
/// platform channel (unavailable in widget tests).
class _FakeTtsService extends TtsService {
  String? lastSpoken;

  @override
  Future<void> speak(String germanText) async {
    lastSpoken = germanText;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  testWidgets('long-pressing a replaced word speaks the German text', (tester) async {
    final fakeTts = _FakeTtsService();
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
        ttsService: fakeTts,
      ),
    ));
    await tester.pump();

    expect(fakeTts.lastSpoken, isNull);

    await tester.longPress(find.text('Haus '));
    await tester.pump();

    expect(fakeTts.lastSpoken, 'Haus');
    // Long-press only triggers pronunciation, not the toggle.
    expect(find.text('Haus '), findsOneWidget);
  });

  testWidgets('long-pressing a non-replaced word does nothing (no crash, nothing spoken)', (tester) async {
    final fakeTts = _FakeTtsService();
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
        ttsService: fakeTts,
      ),
    ));
    await tester.pump();

    await tester.longPress(find.text('bicycle '));
    await tester.pump();

    expect(fakeTts.lastSpoken, isNull);
  });
}
