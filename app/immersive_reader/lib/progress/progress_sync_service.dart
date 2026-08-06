import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/local_db.dart';

/// Thrown by [ProgressSyncService.push]/[ProgressSyncService.pull] when the
/// backend rejects the request (expired token, etc.) - as opposed to a
/// network-level failure, which throws normally (whatever the underlying
/// http/timeout exception is).
class ProgressSyncException implements Exception {
  final String message;
  ProgressSyncException(this.message);

  @override
  String toString() => message;
}

/// Syncs the locally tracked word_progress rows (see WordProgressRepository)
/// for [localUserId] with the Phase 3 backend's authenticated /progress
/// endpoint. [localUserId] is whichever local id owns the rows being
/// synced - normally the device-local placeholder id
/// (lib/progress/local_user_id.dart) until real accounts fully replace it.
/// The bearer [token] passed to push/pull comes from
/// AuthService.currentToken() - this class doesn't know about AuthService,
/// it just needs a token string.
class ProgressSyncService {
  final LocalDb _db;
  final String localUserId;
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  ProgressSyncService(
    this._db,
    this.localUserId, {
    http.Client? client,
    this.baseUrl = 'http://127.0.0.1:8000',
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// Reads every row LocalDb has for [localUserId] and POSTs them to
  /// /progress as {"entries": [...]} - one object per row, same field names
  /// as the LocalDb row minus user_id (the server derives the account from
  /// the bearer [token], not from the payload - see
  /// backend/app/schemas.py's ProgressSyncRequest). Returns the
  /// server-reported synced count. Throws [ProgressSyncException] (with the
  /// backend's `detail` message) on any non-200 response.
  Future<int> push(String token) async {
    final rows = await _db.getAllWordProgress(localUserId);
    final entries = rows.map((row) => {
          'en_word': row['en_word'],
          'exposures': row['exposures'],
          'times_toggled_back': row['times_toggled_back'],
          'times_toggled_forward': row['times_toggled_forward'],
          'last_seen_at': row['last_seen_at'],
          'ease_factor': (row['ease_factor'] as num).toDouble(),
          'interval_days': (row['interval_days'] as num).toDouble(),
          'status': row['status'],
        }).toList();

    final response = await _client
        .post(
          Uri.parse('$baseUrl/progress'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'entries': entries}),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw _syncExceptionFromResponse(response);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['synced'] as int;
  }

  /// GETs /progress and upserts every returned row into LocalDb under
  /// [localUserId] (server wins on conflict - this is a full overwrite per
  /// word, not a merge). Returns the number of rows written. Throws
  /// [ProgressSyncException] (with the backend's `detail` message) on any
  /// non-200 response.
  Future<int> pull(String token) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/progress'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw _syncExceptionFromResponse(response);
    }
    final entries = jsonDecode(response.body) as List<dynamic>;
    for (final dynamic item in entries) {
      final map = item as Map<String, dynamic>;
      await _db.insertOrUpdateWordProgress({
        'user_id': localUserId,
        'en_word': map['en_word'],
        'exposures': map['exposures'],
        'times_toggled_back': map['times_toggled_back'],
        'times_toggled_forward': map['times_toggled_forward'],
        'last_seen_at': map['last_seen_at'],
        'ease_factor': (map['ease_factor'] as num).toDouble(),
        'interval_days': (map['interval_days'] as num).toDouble(),
        'status': map['status'],
      });
    }
    return entries.length;
  }

  ProgressSyncException _syncExceptionFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is String) {
        return ProgressSyncException(detail);
      }
    } catch (_) {
      // fall through to the generic message below
    }
    return ProgressSyncException('Request failed with status ${response.statusCode}');
  }
}
