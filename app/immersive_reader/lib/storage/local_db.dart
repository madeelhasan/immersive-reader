import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  static const _databaseName = 'immersive_reader.db';
  static const _wordProgressTableName = 'word_progress';
  late Database _db;

  Future<void> init() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, _databaseName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDb,
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
}
