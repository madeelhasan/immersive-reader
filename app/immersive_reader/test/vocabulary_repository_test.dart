import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/vocabulary/vocabulary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VocabularyRepository loads the bundled dataset', () async {
    final vocabulary = await VocabularyRepository().load();

    // Floor, not an exact count - the dataset grows over time (SPEC.md 3.2
    // targets ~1,500-2,000 entries across A1-B2; this starts at 100 A1-only).
    expect(vocabulary.length, greaterThanOrEqualTo(100));
    expect(vocabulary['house']?.de, 'Haus');
    expect(vocabulary['house']?.cefrLevel, 'A1');
    expect(vocabulary['house']?.partOfSpeech, 'noun');

    // Lookup must be case-insensitive since it's keyed by lowercase 'en'.
    expect(vocabulary.containsKey('House'), isFalse);
  });

  test('dataset has no duplicate English entries', () async {
    final raw = await rootBundle.loadString('assets/vocab/en_de_starter.json');
    final List<dynamic> entries = jsonDecode(raw) as List<dynamic>;
    final seen = <String>{};
    final duplicates = <String>[];

    for (final entry in entries) {
      final en = ((entry as Map<String, dynamic>)['en'] as String).toLowerCase();
      if (!seen.add(en)) duplicates.add(en);
    }

    expect(duplicates, isEmpty, reason: 'Duplicate en entries silently collide in the lookup map.');
  });

  test('every entry has a valid cefr_level and non-empty fields', () async {
    final raw = await rootBundle.loadString('assets/vocab/en_de_starter.json');
    final List<dynamic> entries = jsonDecode(raw) as List<dynamic>;
    const validLevels = {'A1', 'A2', 'B1', 'B2'};

    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      expect(validLevels.contains(map['cefr_level']), isTrue,
          reason: 'Invalid cefr_level for "${map['en']}": ${map['cefr_level']}');
      expect((map['en'] as String).trim(), isNotEmpty);
      expect((map['de'] as String).trim(), isNotEmpty);
      expect((map['part_of_speech'] as String).trim(), isNotEmpty);
    }
  });
}
