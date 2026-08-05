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
}
