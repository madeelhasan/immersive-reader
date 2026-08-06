import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recent_document.dart';

/// Persists the "recent documents" list (SPEC.md section 3.5/7) -
/// local-only, `SharedPreferences` key `recent_documents`, JSON-encoded,
/// capped at [maxEntries], newest first. Never synced to a backend - see
/// SPEC.md 3.5 for why (local filesystem paths are meaningless cross-device,
/// and the app has no accounts to sync to regardless).
class RecentDocumentsRepository {
  static const maxEntries = 8;
  static const _prefsKey = 'recent_documents';

  /// All recorded entries, newest first.
  Future<List<RecentDocument>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => RecentDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Adds [document] to the front of the list. If a document with the same
  /// `documentId` is already present, it's replaced in place (moved to the
  /// front, its `lastOpenedAt` updated) rather than duplicated. Drops the
  /// oldest entry/entries once the list exceeds [maxEntries].
  Future<void> recordOpened(RecentDocument document) async {
    final current = await getRecent();
    final withoutDuplicate =
        current.where((d) => d.documentId != document.documentId).toList();
    final updated = [document, ...withoutDuplicate].take(maxEntries).toList();
    await _save(updated);
  }

  /// Removes the entry for [documentId], e.g. when its file has since been
  /// moved or deleted (SPEC.md section 7). A no-op if it isn't present.
  Future<void> remove(String documentId) async {
    final current = await getRecent();
    final updated = current.where((d) => d.documentId != documentId).toList();
    await _save(updated);
  }

  Future<void> _save(List<RecentDocument> documents) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(documents.map((d) => d.toJson()).toList()),
    );
  }
}
