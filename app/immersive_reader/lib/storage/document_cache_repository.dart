import 'dart:convert';
import 'dart:io';

import '../models/document_model.dart';
import 'local_db.dart';

/// Caches a parsed DocumentModel keyed by source file path, so reopening an
/// already-parsed file can skip re-parsing entirely. Invalidated
/// automatically if the source file's size or modification time changes
/// since it was cached - no explicit invalidation call needed.
class DocumentCacheRepository {
  final LocalDb _db;

  DocumentCacheRepository(this._db);

  /// Returns the cached document for [filePath], or null on a cache miss -
  /// which includes "the source file changed since caching" and "the
  /// cached JSON is somehow unreadable" (fails safe: callers should treat
  /// null as "just parse it normally," not as an error).
  Future<DocumentModel?> get(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final row = await _db.getCachedDocument(filePath);
    if (row == null) return null;

    final stat = await file.stat();
    if (row['mtime'] != stat.modified.millisecondsSinceEpoch || row['size'] != stat.size) {
      return null;
    }

    try {
      final decoded = jsonDecode(row['document_json'] as String) as Map<String, dynamic>;
      return DocumentModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String filePath, DocumentModel document) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    final stat = await file.stat();
    await _db.putCachedDocument(
      filePath: filePath,
      mtime: stat.modified.millisecondsSinceEpoch,
      size: stat.size,
      documentJson: jsonEncode(document.toJson()),
    );
  }
}
