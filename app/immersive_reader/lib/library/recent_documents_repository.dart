import '../models/recent_document.dart';

/// Persists the "recent documents" list (SPEC.md section 3.5/7) -
/// local-only, `SharedPreferences` key `recent_documents`, JSON-encoded,
/// capped at [maxEntries], newest first. Never synced to a backend - see
/// SPEC.md 3.5 for why (local filesystem paths are meaningless cross-device,
/// and the app has no accounts to sync to regardless).
class RecentDocumentsRepository {
  static const maxEntries = 8;

  /// All recorded entries, newest first.
  Future<List<RecentDocument>> getRecent() async {
    throw UnimplementedError();
  }

  /// Adds [document] to the front of the list. If a document with the same
  /// `documentId` is already present, it's replaced in place (moved to the
  /// front, its `lastOpenedAt` updated) rather than duplicated. Drops the
  /// oldest entry/entries once the list exceeds [maxEntries].
  Future<void> recordOpened(RecentDocument document) async {
    throw UnimplementedError();
  }

  /// Removes the entry for [documentId], e.g. when its file has since been
  /// moved or deleted (SPEC.md section 7). A no-op if it isn't present.
  Future<void> remove(String documentId) async {
    throw UnimplementedError();
  }
}
