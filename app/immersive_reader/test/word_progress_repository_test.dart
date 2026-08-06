import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:immersive_reader/progress/sm2_scheduler.dart';
import 'package:immersive_reader/progress/word_progress_repository.dart';
import 'package:immersive_reader/storage/local_db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDb db;
  late WordProgressRepository repo;

  setUp(() async {
    db = LocalDb();
    await db.init(path: inMemoryDatabasePath);
    repo = WordProgressRepository(db, 'user-1');
  });

  test('getProgress returns a fresh new-word state for a word never seen', () async {
    final progress = await repo.getProgress('house');
    expect(progress.exposures, 0);
    expect(progress.status, 'new');
    expect(progress.easeFactor, 2.5);
  });

  test('recordExposure persists the updated state and returns it', () async {
    final result = await repo.recordExposure('house', ExposureOutcome.neutral);
    expect(result.exposures, 1);
    expect(result.status, 'introduced');

    final reloaded = await repo.getProgress('house');
    expect(reloaded.exposures, 1);
    expect(reloaded.status, 'introduced');
    expect(reloaded.easeFactor, result.easeFactor);
    expect(reloaded.intervalDays, result.intervalDays);
  });

  test('repeated exposures accumulate against the persisted state', () async {
    await repo.recordExposure('house', ExposureOutcome.neutral);
    await repo.recordExposure('house', ExposureOutcome.neutral);
    final third = await repo.recordExposure('house', ExposureOutcome.neutral);
    expect(third.exposures, 3);
    expect(third.status, 'reinforced');
  });

  test('progress is isolated per user_id', () async {
    await repo.recordExposure('house', ExposureOutcome.neutral);
    final otherUser = WordProgressRepository(db, 'user-2');
    final untouched = await otherUser.getProgress('house');
    expect(untouched.exposures, 0);
    expect(untouched.status, 'new');
  });

  test('progress is isolated per word', () async {
    await repo.recordExposure('house', ExposureOutcome.neutral);
    final otherWord = await repo.getProgress('bicycle');
    expect(otherWord.exposures, 0);
  });

  test('getAllProgress returns every tracked word for the user', () async {
    await repo.recordExposure('house', ExposureOutcome.neutral);
    await repo.recordExposure('bicycle', ExposureOutcome.toggledBack);
    final all = await repo.getAllProgress();
    expect(all.keys, containsAll(['house', 'bicycle']));
    expect(all['house']!.exposures, 1);
    expect(all['bicycle']!.timesToggledBack, 1);
  });
}
