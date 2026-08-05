import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/vocabulary/vocabulary_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('VocabularyRepository loads the bundled starter dataset', () async {
    final vocabulary = await VocabularyRepository().load();

    expect(vocabulary.length, 100);
    expect(vocabulary['house']?.de, 'Haus');
    expect(vocabulary['house']?.cefrLevel, 'A1');
    expect(vocabulary['house']?.partOfSpeech, 'noun');

    // Lookup must be case-insensitive since it's keyed by lowercase 'en'.
    expect(vocabulary.containsKey('House'), isFalse);
  });
}
