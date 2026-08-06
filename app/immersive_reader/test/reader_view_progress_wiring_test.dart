import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/document_model.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/progress/sm2_scheduler.dart';
import 'package:immersive_reader/progress/word_progress_repository.dart';
import 'package:immersive_reader/reader/reader_controller.dart';
import 'package:immersive_reader/reader/reader_view.dart';
import 'package:immersive_reader/storage/local_db.dart';

class _RecordedCall {
  final String enWord;
  final ExposureOutcome outcome;
  _RecordedCall(this.enWord, this.outcome);

  @override
  bool operator ==(Object other) =>
      other is _RecordedCall && other.enWord == enWord && other.outcome == outcome;

  @override
  int get hashCode => Object.hash(enWord, outcome);

  @override
  String toString() => '_RecordedCall($enWord, $outcome)';
}

class _FakeWordProgressRepository extends WordProgressRepository {
  _FakeWordProgressRepository() : super(LocalDb(), 'test-user');

  final List<_RecordedCall> calls = [];

  @override
  Future<WordProgress> recordExposure(String enWord, ExposureOutcome outcome) async {
    calls.add(_RecordedCall(enWord, outcome));
    return const WordProgress();
  }

  @override
  Future<WordProgress> getProgress(String enWord) async => const WordProgress();

  @override
  Future<Map<String, WordProgress>> getAllProgress() async => {};
}

DocumentModel _buildDocument() {
  final token = Token(tokenId: 't1', text: 'house', isWord: true, positionIndex: 0);
  return DocumentModel(
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
}

Future<_FakeWordProgressRepository> _pumpReader(WidgetTester tester) async {
  final fakeRepo = _FakeWordProgressRepository();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ReaderView(
        document: _buildDocument(),
        controller: ReaderController(),
        replacements: const {'t1': 'Haus'},
        wordProgressRepository: fakeRepo,
      ),
    ),
  ));
  await tester.pump();
  return fakeRepo;
}

void main() {
  testWidgets('building a replaced token records exactly one neutral exposure', (tester) async {
    final fakeRepo = await _pumpReader(tester);
    expect(fakeRepo.calls, [_RecordedCall('house', ExposureOutcome.neutral)]);
    expect(find.text('Haus '), findsOneWidget);
  });

  testWidgets('a rebuild (font size change) does not double-record the exposure', (tester) async {
    final fakeRepo = await _pumpReader(tester);
    await tester.tap(find.byTooltip('Increase font size'));
    await tester.pump();
    expect(fakeRepo.calls, [_RecordedCall('house', ExposureOutcome.neutral)]);
  });

  testWidgets('tapping a replaced word toggles it to English and records toggledBack', (tester) async {
    final fakeRepo = await _pumpReader(tester);
    await tester.tap(find.text('Haus '));
    await tester.pump();
    expect(find.text('house '), findsOneWidget);
    expect(fakeRepo.calls, [
      _RecordedCall('house', ExposureOutcome.neutral),
      _RecordedCall('house', ExposureOutcome.toggledBack),
    ]);
  });

  testWidgets('tapping again toggles back to German and records toggledForward', (tester) async {
    final fakeRepo = await _pumpReader(tester);
    await tester.tap(find.text('Haus '));
    await tester.pump();
    await tester.tap(find.text('house '));
    await tester.pump();
    expect(find.text('Haus '), findsOneWidget);
    expect(fakeRepo.calls, [
      _RecordedCall('house', ExposureOutcome.neutral),
      _RecordedCall('house', ExposureOutcome.toggledBack),
      _RecordedCall('house', ExposureOutcome.toggledForward),
    ]);
  });
}
