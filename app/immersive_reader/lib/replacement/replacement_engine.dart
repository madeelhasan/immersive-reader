import 'dart:math';

import '../models/token.dart';
import '../models/vocabulary_entry.dart';

class ReplacementEngine {
  Map<String, String> selectReplacements(
    List<Token> tokens,
    Map<String, VocabularyEntry> vocabulary, {
    double rate = 0.15,
    Random? random,
  }) {
    final rng = random ?? Random();
    final result = <String, String>{};

    for (final token in tokens) {
      if (!token.isWord) {
        continue;
      }

      final lower = token.text.toLowerCase();
      final entry = vocabulary[lower];
      if (entry == null) {
        continue;
      }

      if (rng.nextDouble() < rate) {
        result[token.tokenId] = entry.de;
      }
    }

    return result;
  }
}
