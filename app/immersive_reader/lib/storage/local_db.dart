import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  static const _databaseName = 'immersive_reader.db';
  static const _wordProgressTableName = 'word_progress';
  late Database _db;

  /// [path] is injectable for tests (e.g. sqflite_common_ffi's
  /// inMemoryDatabasePath) - defaults to the real on-disk database.
  Future<void> init({String? path}) async {
    final resolvedPath =
        path ?? join(await getDatabasesPath(), _databaseName);
    _db = await openDatabase(
      resolvedPath,
      version: 1,
      onCreate: _createDb,
      // false so tests opening inMemoryDatabasePath repeatedly each get an
      // isolated database instead of sqflite's cached single instance per path.
      singleInstance: false,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
CREATE TABLE $_wordProgressTableName (
  user_id TEXT NOT NULL,
  en_word TEXT NOT NULL,
  exposures INTEGER DEFAULT 0,
  times_toggled_back INTEGER DEFAULT 0,
  times_toggled_forward INTEGER DEFAULT 0,
  last_seen_at TIMESTAMP,
  ease_factor REAL DEFAULT 2.5,
  interval_days REAL DEFAULT 1,
  status TEXT DEFAULT 'new',
  PRIMARY KEY (user_id, en_word)
)
''');
  }

  Future<void> insertOrUpdateWordProgress(
      Map<String, dynamic> wordProgress) async {
    await _db.insert(
      _wordProgressTableName,
      wordProgress,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getWordProgress(
      String userId, String enWord) async {
    final rows = await _db.query(
      _wordProgressTableName,
      where: 'user_id = ? AND en_word = ?',
      whereArgs: [userId, enWord],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllWordProgress(String userId) async {
    return _db.query(
      _wordProgressTableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
