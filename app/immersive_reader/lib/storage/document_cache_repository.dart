import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;

import '../models/document_model.dart';
import 'local_db.dart';

/// Off the main isolate via compute() (see parsers/background_parse.dart for
/// why this matters) - encode/decode of a large document's JSON is plain
/// synchronous CPU work otherwise, same class of freeze as an uncached parse.
DocumentModel _decodeDocument(String json) {
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  return DocumentModel.fromJson(decoded);
}

String _encodeDocument(DocumentModel document) => jsonEncode(document.toJson());

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
      return await compute(_decodeDocument, row['document_json'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String filePath, DocumentModel document) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    final stat = await file.stat();
    final documentJson = await compute(_encodeDocument, document);
    await _db.putCachedDocument(
      filePath: filePath,
      mtime: stat.modified.millisecondsSinceEpoch,
      size: stat.size,
      documentJson: documentJson,
    );
  }
}
