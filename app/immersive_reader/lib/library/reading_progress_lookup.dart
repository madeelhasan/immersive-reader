import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';
import '../models/recent_document.dart';
import '../reader/reader_prefs_keys.dart';

/// Answers "does this recently-opened book still have a bookmark worth
/// resuming from?" for the home screen's "Continue reading" section
/// (SPEC.md section 7 addendum) - without opening or re-parsing the
/// document. Bookmarks and scroll position are both stored per-document in
/// SharedPreferences under keys ReaderView already owns; reusing them here
/// needs no new plumbing, and since SharedPreferences.getInstance() is a
/// cached in-memory singleton after the first await, checking this for
/// every recent document costs no extra disk I/O.
class ReadingProgressLookup {
  /// A book counts as finished once the last known scroll position is at
  /// least this far through it - past this point a leftover bookmark isn't
  /// worth surfacing as "in progress" anymore.
  static const double completionThreshold = 0.95;

  final SharedPreferences _prefs;

  ReadingProgressLookup(this._prefs);

  bool hasBookmarks(String documentId) {
    final raw = _prefs.getString(bookmarksPrefsKey(documentId));
    if (raw == null) return false;
    return Bookmark.decodeList(raw).isNotEmpty;
  }

  /// False whenever completion can't be determined (no paragraph count
  /// recorded - a legacy entry from before this field existed - or no
  /// scroll position saved yet) - the safer default here is to keep
  /// treating the book as still in progress rather than silently hiding it.
  bool isCompleted(RecentDocument document) {
    final paragraphCount = document.paragraphCount;
    if (paragraphCount == null || paragraphCount <= 1) return false;
    final index = _prefs.getInt(scrollIndexPrefsKey(document.documentId));
    if (index == null) return false;
    return (index / (paragraphCount - 1)) >= completionThreshold;
  }

  bool isInProgress(RecentDocument document) =>
      hasBookmarks(document.documentId) && !isCompleted(document);
}
