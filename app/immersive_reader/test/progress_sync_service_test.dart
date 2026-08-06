import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:immersive_reader/progress/progress_sync_service.dart';
import 'package:immersive_reader/progress/sm2_scheduler.dart';
import 'package:immersive_reader/progress/word_progress_repository.dart';
import 'package:immersive_reader/storage/local_db.dart';

/// Same fake-client pattern as vocabulary_repository_test.dart.
class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalDb db;

  setUp(() async {
    db = LocalDb();
    await db.init(path: inMemoryDatabasePath);
  });

  group('push', () {
    test('sends every locally tracked word with the auth header, returns synced count', () async {
      final repo = WordProgressRepository(db, 'local-user-1');
      await repo.recordExposure('house', ExposureOutcome.neutral);
      await repo.recordExposure('bicycle', ExposureOutcome.toggledForward);

      final captured = <Map<String, dynamic>>[];
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/progress');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer jwt-abc');
        final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        final entries = (body['entries'] as List).cast<Map<String, dynamic>>();
        captured.addAll(entries);
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'user_id': 'acct-1', 'synced': entries.length}))),
          200,
        );
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      final synced = await service.push('jwt-abc');

      expect(synced, 2);
      expect(captured.length, 2);
      final house = captured.firstWhere((e) => e['en_word'] == 'house');
      expect(house['exposures'], 1);
      expect(house['status'], 'introduced');
      expect(house['ease_factor'], 2.5);
      expect(house.containsKey('user_id'), isFalse,
          reason: 'server derives the account from the bearer token, not the payload');
      final bicycle = captured.firstWhere((e) => e['en_word'] == 'bicycle');
      expect(bicycle['times_toggled_forward'], 1);
    });

    test('throws ProgressSyncException with the backend detail on failure', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode({'detail': 'Invalid or expired token'});
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 401);
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      expect(
        () => service.push('bad-token'),
        throwsA(isA<ProgressSyncException>()
            .having((e) => e.message, 'message', 'Invalid or expired token')),
      );
    });

    test('sends an empty entries list when there is no local progress', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        expect(body['entries'], isEmpty);
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'user_id': 'acct-1', 'synced': 0}))),
          200,
        );
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      expect(await service.push('jwt-abc'), 0);
    });
  });

  group('pull', () {
    test('writes downloaded entries into the local DB under localUserId', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:8000/progress');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer jwt-abc');
        final body = jsonEncode([
          {
            'en_word': 'house',
            'exposures': 4,
            'times_toggled_back': 1,
            'times_toggled_forward': 2,
            'last_seen_at': '2026-01-01T00:00:00.000Z',
            'ease_factor': 2.35,
            'interval_days': 6.0,
            'status': 'reinforced',
          },
        ]);
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      final pulled = await service.pull('jwt-abc');

      expect(pulled, 1);
      final repo = WordProgressRepository(db, 'local-user-1');
      final progress = await repo.getProgress('house');
      expect(progress.exposures, 4);
      expect(progress.status, 'reinforced');
      expect(progress.easeFactor, 2.35);
      expect(progress.intervalDays, 6.0);
    });

    test('overwrites existing local rows for the same word (server wins)', () async {
      final repo = WordProgressRepository(db, 'local-user-1');
      await repo.recordExposure('house', ExposureOutcome.neutral); // local: exposures=1

      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode([
          {
            'en_word': 'house',
            'exposures': 10,
            'times_toggled_back': 0,
            'times_toggled_forward': 0,
            'last_seen_at': '2026-01-01T00:00:00.000Z',
            'ease_factor': 2.5,
            'interval_days': 1.0,
            'status': 'learned',
          },
        ]);
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      await service.pull('jwt-abc');

      final progress = await repo.getProgress('house');
      expect(progress.exposures, 10);
      expect(progress.status, 'learned');
    });

    test('does not affect other local user ids', () async {
      final otherRepo = WordProgressRepository(db, 'someone-else');
      await otherRepo.recordExposure('house', ExposureOutcome.neutral);

      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode([
          {
            'en_word': 'house',
            'exposures': 99,
            'times_toggled_back': 0,
            'times_toggled_forward': 0,
            'last_seen_at': '2026-01-01T00:00:00.000Z',
            'ease_factor': 2.5,
            'interval_days': 1.0,
            'status': 'learned',
          },
        ]);
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      await service.pull('jwt-abc');

      final untouched = await otherRepo.getProgress('house');
      expect(untouched.exposures, 1);
    });

    test('throws ProgressSyncException with the backend detail on failure', () async {
      final fakeClient = _FakeHttpClient((request) async {
        final body = jsonEncode({'detail': 'Invalid or expired token'});
        return http.StreamedResponse(Stream.value(utf8.encode(body)), 401);
      });

      final service = ProgressSyncService(db, 'local-user-1', client: fakeClient);
      expect(
        () => service.pull('bad-token'),
        throwsA(isA<ProgressSyncException>()
            .having((e) => e.message, 'message', 'Invalid or expired token')),
      );
    });
  });
}
