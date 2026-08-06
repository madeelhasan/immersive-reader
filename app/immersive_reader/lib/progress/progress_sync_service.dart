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
    throw UnimplementedError();
  }

  /// GETs /progress and upserts every returned row into LocalDb under
  /// [localUserId] (server wins on conflict - this is a full overwrite per
  /// word, not a merge). Returns the number of rows written. Throws
  /// [ProgressSyncException] (with the backend's `detail` message) on any
  /// non-200 response.
  Future<int> pull(String token) async {
    throw UnimplementedError();
  }
}
