/// SharedPreferences key formats for per-document reader state, shared
/// between ReaderView (which owns writing them) and anything else that
/// needs to read them without opening the document - e.g. the home
/// screen's "Continue reading" section (SPEC.md section 7 addendum),
/// which checks bookmarks/scroll progress for every recent document.
/// Centralized here so both sides can't drift out of sync.
String scrollIndexPrefsKey(String documentId) => 'scroll_index_$documentId';
String bookmarksPrefsKey(String documentId) => 'bookmarks_$documentId';
