import '../storage/local_db.dart';
import 'sm2_scheduler.dart';

/// Bridges the pure Sm2Scheduler algorithm to persisted storage: loads the
/// current WordProgress for a word (defaulting to a fresh 'new' state if
/// never seen), runs it through the scheduler, and writes the result back.
class WordProgressRepository {
  final LocalDb _db;
  final String userId;
  final Sm2Scheduler _scheduler = Sm2Scheduler();

  WordProgressRepository(this._db, this.userId);

  Future<WordProgress> getProgress(String enWord) async {
    final row = await _db.getWordProgress(userId, enWord);
    return row == null ? const WordProgress() : _fromRow(row);
  }

  Future<WordProgress> recordExposure(
      String enWord, ExposureOutcome outcome) async {
    final current = await getProgress(enWord);
    final updated = _scheduler.recordExposure(current, outcome);
    await _db.insertOrUpdateWordProgress(_toRow(enWord, updated));
    return updated;
  }

  Future<Map<String, WordProgress>> getAllProgress() async {
    final rows = await _db.getAllWordProgress(userId);
    return {
      for (final row in rows) row['en_word'] as String: _fromRow(row),
    };
  }

  Map<String, dynamic> _toRow(String enWord, WordProgress progress) => {
        'user_id': userId,
        'en_word': enWord,
        'exposures': progress.exposures,
        'times_toggled_back': progress.timesToggledBack,
        'times_toggled_forward': progress.timesToggledForward,
        'last_seen_at': DateTime.now().toIso8601String(),
        'ease_factor': progress.easeFactor,
        'interval_days': progress.intervalDays,
        'status': progress.status,
      };

  WordProgress _fromRow(Map<String, dynamic> row) => WordProgress(
        exposures: row['exposures'] as int,
        timesToggledBack: row['times_toggled_back'] as int,
        timesToggledForward: row['times_toggled_forward'] as int,
        easeFactor: (row['ease_factor'] as num).toDouble(),
        intervalDays: (row['interval_days'] as num).toDouble(),
        status: row['status'] as String,
      );
}
