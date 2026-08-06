import 'dart:math';

import '../models/token.dart';
import '../models/vocabulary_entry.dart';

class ReplacementEngine {
  // CEFR levels are cumulative: a reader at level N is assumed to also
  // handle every level below N (SPEC.md section 4). Index in this list is
  // used both to test eligibility (entry level <= selected level) and to
  // look up the level's base replacement rate.
  static const levelOrder = ['A1', 'A2', 'B1', 'B2'];
  static const levelRates = {'A1': 0.10, 'A2': 0.15, 'B1': 0.20, 'B2': 0.25};

  Map<String, String> selectReplacements(
    List<Token> tokens,
    Map<String, VocabularyEntry> vocabulary, {
    String germanLevel = 'B2',
    double? rate,
    Random? random,
  }) {
    final rng = random ?? Random();
    final result = <String, String>{};
    final effectiveRate = rate ?? levelRates[germanLevel] ?? levelRates['B2']!;
    final maxLevelIndex = levelOrder.indexOf(germanLevel);

    for (final token in tokens) {
      if (!token.isWord) {
        continue;
      }

      final lower = token.text.toLowerCase();
      final entry = vocabulary[lower];
      if (entry == null) {
        continue;
      }

      final entryLevelIndex = levelOrder.indexOf(entry.cefrLevel);
      if (entryLevelIndex == -1 || entryLevelIndex > maxLevelIndex) {
        continue;
      }

      if (rng.nextDouble() < effectiveRate) {
        result[token.tokenId] = entry.de;
      }
    }

    return result;
  }
}
