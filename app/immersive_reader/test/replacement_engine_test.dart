import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/models/vocabulary_entry.dart';
import 'package:immersive_reader/progress/sm2_scheduler.dart';
import 'package:immersive_reader/replacement/replacement_engine.dart';

Token _token(String text, {bool isWord = true}) => Token(
      tokenId: text,
      text: text,
      isWord: isWord,
      positionIndex: 0,
    );

Token _tokenAt(String text, int positionIndex, {bool isWord = true}) => Token(
      tokenId: text,
      text: text,
      isWord: isWord,
      positionIndex: positionIndex,
    );

void main() {
  final vocabulary = {
    'house': VocabularyEntry(en: 'house', de: 'Haus', cefrLevel: 'A1', partOfSpeech: 'noun'),
  };

  test('never replaces words missing from the vocabulary', () {
    final tokens = [_token('bicycle')];
    final result = ReplacementEngine().selectReplacements(
      tokens,
      vocabulary,
      rate: 1.0,
      random: Random(1),
    );
    expect(result, isEmpty);
  });

  test('never replaces non-word tokens even if the text matches', () {
    final tokens = [_token('house', isWord: false)];
    final result = ReplacementEngine().selectReplacements(
      tokens,
      vocabulary,
      rate: 1.0,
      random: Random(1),
    );
    expect(result, isEmpty);
  });

  test('matches vocabulary case-insensitively and maps tokenId to the German translation', () {
    final tokens = [_token('House')];
    final result = ReplacementEngine().selectReplacements(
      tokens,
      vocabulary,
      rate: 1.0,
      random: Random(1),
    );
    expect(result['House'], 'Haus');
  });

  test('never selects a word when rate is 0', () {
    final tokens = [_token('house')];
    final result = ReplacementEngine().selectReplacements(
      tokens,
      vocabulary,
      rate: 0.0,
      random: Random(1),
    );
    expect(result, isEmpty);
  });

  group('germanLevel eligibility (SPEC.md section 4.1)', () {
    final mixedVocabulary = {
      'house': VocabularyEntry(en: 'house', de: 'Haus', cefrLevel: 'A1', partOfSpeech: 'noun'),
      'journey': VocabularyEntry(en: 'journey', de: 'die Reise', cefrLevel: 'A2', partOfSpeech: 'noun'),
      'employment': VocabularyEntry(en: 'employment', de: 'die Beschäftigung', cefrLevel: 'B1', partOfSpeech: 'noun'),
      'sovereignty': VocabularyEntry(en: 'sovereignty', de: 'die Souveränität', cefrLevel: 'B2', partOfSpeech: 'noun'),
    };
    final tokens = mixedVocabulary.keys.map(_token).toList();

    test('A1 level only makes A1 words eligible', () {
      final result = ReplacementEngine().selectReplacements(
        tokens,
        mixedVocabulary,
        germanLevel: 'A1',
        rate: 1.0,
        random: Random(1),
      );
      expect(result.keys, {'house'});
    });

    test('B1 level makes A1/A2/B1 words eligible but not B2 (cumulative)', () {
      final result = ReplacementEngine().selectReplacements(
        tokens,
        mixedVocabulary,
        germanLevel: 'B1',
        rate: 1.0,
        random: Random(1),
      );
      expect(result.keys, {'house', 'journey', 'employment'});
    });

    test('B2 level makes every level eligible', () {
      final result = ReplacementEngine().selectReplacements(
        tokens,
        mixedVocabulary,
        germanLevel: 'B2',
        rate: 1.0,
        random: Random(1),
      );
      expect(result.keys, {'house', 'journey', 'employment', 'sovereignty'});
    });

    test('base rate scales with germanLevel when rate is not overridden', () {
      expect(ReplacementEngine.levelRates['A1'], 0.10);
      expect(ReplacementEngine.levelRates['A2'], 0.15);
      expect(ReplacementEngine.levelRates['B1'], 0.20);
      expect(ReplacementEngine.levelRates['B2'], 0.25);
    });
  });

  // ---- Phase 4 tests (SPEC.md section 4.2) ----

  test('probabilityFor new at progress 0.0 returns 0.05', () {
    expect(ReplacementEngine().probabilityFor('new', 0.0), closeTo(0.05, 1e-9));
  });

  test('probabilityFor new at progress 1.0 returns 0.40', () {
    expect(ReplacementEngine().probabilityFor('new', 1.0), closeTo(0.40, 1e-9));
  });

  test('probabilityFor introduced at progress 0.5 returns 0.225', () {
    expect(ReplacementEngine().probabilityFor('introduced', 0.5), closeTo(0.225, 1e-9));
  });

  test('probabilityFor learned at progress 0.0 returns 0.85', () {
    expect(ReplacementEngine().probabilityFor('learned', 0.0), closeTo(0.85, 1e-9));
  });

  test('probabilityFor learned at progress 1.0 returns 0.85', () {
    expect(ReplacementEngine().probabilityFor('learned', 1.0), closeTo(0.85, 1e-9));
  });

  test('probabilityFor reinforced at progress 0.0 returns 0.45', () {
    expect(ReplacementEngine().probabilityFor('reinforced', 0.0), closeTo(0.45, 1e-9));
  });

  test('probabilityFor reinforced at progress 1.0 returns 0.625', () {
    expect(ReplacementEngine().probabilityFor('reinforced', 1.0), closeTo(0.625, 1e-9));
  });

  test('probabilityFor unknown status at progress 0.5 returns 0.225', () {
    expect(ReplacementEngine().probabilityFor('unknown-status-xyz', 0.5), closeTo(0.225, 1e-9));
  });

  test('never replaces words missing from the vocabulary (with progress)', () {
    final tokens = [_token('bicycle')];
    final result = ReplacementEngine().selectReplacementsWithProgress(
      tokens,
      vocabulary,
      {},
      random: Random(1),
    );
    expect(result, isEmpty);
  });

  test('a learned word at document position 0 still gets a high replacement chance', () {
    final tokens = [_tokenAt('house', 0)];
    final progress = {'house': const WordProgress(status: 'learned')};
    int hits = 0;
    const trials = 1000;
    for (var i = 0; i < trials; i++) {
      final result = ReplacementEngine().selectReplacementsWithProgress(
        tokens,
        vocabulary,
        progress,
        random: Random(i),
      );
      if (result.containsKey('house')) {
        hits++;
      }
    }
    expect(hits, greaterThan(750));
    expect(hits, lessThan(950));
  });

  test("a word above the reader's declared level is never replaced even with learned status", () {
    final vocab = {
      'house': VocabularyEntry(en: 'house', de: 'Haus', cefrLevel: 'A1', partOfSpeech: 'noun'),
      'sovereignty': VocabularyEntry(en: 'sovereignty', de: 'die Souveränität', cefrLevel: 'B2', partOfSpeech: 'noun'),
    };
    final tokens = [_tokenAt('sovereignty', 0)];
    final progress = {'sovereignty': const WordProgress(status: 'learned')};
    final result = ReplacementEngine().selectReplacementsWithProgress(
      tokens,
      vocab,
      progress,
      germanLevel: 'A1',
      random: Random(1),
    );
    expect(result, isEmpty);
  });
}
