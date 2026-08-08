import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:immersive_reader/dictionary/dictionary_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<DictionaryRepository> buildRepoWith(List<(String headword, String entry)> rows) async {
    // singleInstance: false - sqflite otherwise caches one Database per
    // path, so every test opening the same literal ":memory:" path would
    // share (and pollute) the same connection.
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY,
        headword TEXT NOT NULL,
        headword_lower TEXT NOT NULL,
        entry TEXT NOT NULL
      )
    ''');
    for (final (headword, entry) in rows) {
      await db.insert('entries', {'headword': headword, 'headword_lower': headword.toLowerCase(), 'entry': entry});
    }
    return DictionaryRepository(testDatabase: db);
  }

  test('finds a matching entry case-insensitively', () async {
    final repo = await buildRepoWith([('book', 'Buch <neut>')]);

    final results = await repo.lookup('BOOK');

    expect(results, hasLength(1));
    expect(results.first.headword, 'book');
    expect(results.first.definition, 'Buch <neut>');
  });

  test('returns every entry for a word with multiple senses', () async {
    final repo = await buildRepoWith([
      ('book', 'Buch <neut>'),
      ('book', 'jdn. einbuchten <v, trans> [ugs.]'),
    ]);

    final results = await repo.lookup('book');

    expect(results, hasLength(2));
  });

  test('returns an empty list for a word not in the dictionary', () async {
    final repo = await buildRepoWith([('book', 'Buch <neut>')]);

    expect(await repo.lookup('zzznotaword'), isEmpty);
  });

  test('returns an empty list for blank input without querying', () async {
    final repo = await buildRepoWith([('book', 'Buch <neut>')]);

    expect(await repo.lookup('   '), isEmpty);
    expect(await repo.lookup(''), isEmpty);
  });

  test('trims surrounding whitespace before looking up', () async {
    final repo = await buildRepoWith([('book', 'Buch <neut>')]);

    final results = await repo.lookup('  book  ');

    expect(results, hasLength(1));
  });
}
