import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/models/token.dart';
import 'package:immersive_reader/models/vocabulary_entry.dart';
import 'package:immersive_reader/replacement/replacement_engine.dart';

Token _token(String text, {bool isWord = true}) => Token(
      tokenId: text,
      text: text,
      isWord: isWord,
      positionIndex: 0,
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
}
