import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'dictionary_entry.dart';

/// Offline English -> German word lookup, backed by a local build of
/// FreeDict's eng-deu dictionary (GPLv3/AGPLv3 - see
/// assets/dictionary/licenses/FREEDICT-COPYING.txt and the README credits
/// section) - 459,731 entries, converted from FreeDict's own dictd release
/// into a flat SQLite table by a one-time offline build script (not
/// shipped, not run on the user's machine).
///
/// The database ships gzip-compressed as a Flutter asset (~22MB vs. ~92MB
/// uncompressed) since SQLite can't query an asset directly either way -
/// the first lookup in a session decompresses it once into the same
/// on-disk directory sqflite already uses for LocalDb, and every lookup
/// after that (this session or a later one) opens the already-decompressed
/// file directly.
class DictionaryRepository {
  static const _assetPath = 'assets/dictionary/freedict_eng_deu.sqlite.gz';
  static const _dbFileName = 'freedict_eng_deu.sqlite';

  /// Injectable for tests, so they can point at a small pre-built database
  /// instead of decompressing the real 22MB asset - same spirit as
  /// LocalDb's injectable `path`.
  final Database? _testDatabase;

  Database? _db;

  DictionaryRepository({Database? testDatabase}) : _testDatabase = testDatabase;

  Future<void> _ensureOpen() async {
    if (_db != null) return;
    if (_testDatabase != null) {
      _db = _testDatabase;
      return;
    }
    final resolvedPath = p.join(await getDatabasesPath(), _dbFileName);
    if (!await File(resolvedPath).exists()) {
      final compressed = await rootBundle.load(_assetPath);
      final bytes = compressed.buffer.asUint8List(compressed.offsetInBytes, compressed.lengthInBytes);
      final decompressed = GZipDecoder().decodeBytes(bytes);
      await File(resolvedPath).create(recursive: true);
      await File(resolvedPath).writeAsBytes(decompressed, flush: true);
    }
    _db = await openDatabase(resolvedPath, singleInstance: false);
  }

  /// Case-insensitive exact-headword lookup. A word can have several
  /// entries (different senses, parts of speech, or homographs) - all are
  /// returned, in whatever order FreeDict's own source listed them.
  Future<List<DictionaryEntry>> lookup(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return [];
    await _ensureOpen();
    final rows = await _db!.query(
      'entries',
      where: 'headword_lower = ?',
      whereArgs: [trimmed.toLowerCase()],
    );
    return rows
        .map((row) => DictionaryEntry(headword: row['headword'] as String, definition: row['entry'] as String))
        .toList();
  }
}
