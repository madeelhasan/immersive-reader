import 'dart:math';

import '../models/token.dart';
import '../models/vocabulary_entry.dart';
import '../progress/sm2_scheduler.dart';

class ReplacementEngine {
  // CEFR levels are cumulative: a reader at level N is assumed to also
  // handle every level below N (SPEC.md section 4). Index in this list is
  // used both to test eligibility (entry level <= selected level) and to
  // look up the level's base replacement rate.
  static const levelOrder = ['A1', 'A2', 'B1', 'B2'];
  static const levelRates = {'A1': 0.10, 'A2': 0.15, 'B1': 0.20, 'B2': 0.25};

  // Phase 4 depth/status constants (SPEC.md section 4.2)
  static const double depthBaseRate = 0.05;
  static const double depthCeilingRate = 0.40;
  static const double learnedFlatRate = 0.85;
  static const double reinforcedBlend = 0.5;

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

  double depthMultiplier(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    return depthBaseRate + (depthCeilingRate - depthBaseRate) * clamped;
  }

  double probabilityFor(String status, double progress) {
    final depth = depthMultiplier(progress);
    switch (status) {
      case 'learned':
        return learnedFlatRate;
      case 'reinforced':
        return depth + (learnedFlatRate - depth) * reinforcedBlend;
      default: // 'new', 'introduced', or any unrecognized status
        return depth;
    }
  }

  Map<String, String> selectReplacementsWithProgress(
    List<Token> tokens,
    Map<String, VocabularyEntry> vocabulary,
    Map<String, WordProgress> wordProgress, {
    String germanLevel = 'B2',
    Random? random,
  }) {
    final rng = random ?? Random();
    final result = <String, String>{};
    final maxLevelIndex = levelOrder.indexOf(germanLevel);
    final totalTokens = tokens.length;

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

      // compute progress
      double progress;
      if (totalTokens <= 1) {
        progress = 0.0;
      } else {
        progress = token.positionIndex / (totalTokens - 1);
        progress = progress.clamp(0.0, 1.0);
      }

      final status = wordProgress[lower]?.status ?? 'new';
      final probability = probabilityFor(status, progress);

      if (rng.nextDouble() < probability) {
        result[token.tokenId] = entry.de;
      }
    }

    return result;
  }
}
