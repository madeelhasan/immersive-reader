import 'dart:convert';

/// A saved position within a document, expressed as a scroll fraction
/// (0.0-1.0) consistent with the rest of ReaderView's navigation
/// (_jumpToFraction, chapter markers). isCurrentPosition marks the single
/// distinguished "auto-advancing" bookmark (see ReaderView._addBookmark) -
/// manually-placed bookmarks always have it false, and there is never more
/// than one true at a time per document.
class Bookmark {
  final String id;
  final double fraction;
  final bool isCurrentPosition;

  Bookmark({
    required this.id,
    required this.fraction,
    this.isCurrentPosition = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fraction': fraction,
        'is_current_position': isCurrentPosition,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        fraction: (json['fraction'] as num).toDouble(),
        isCurrentPosition: json['is_current_position'] as bool? ?? false,
      );

  /// Decodes the JSON-encoded list stored under a document's
  /// `bookmarksPrefsKey` (reader_prefs_keys.dart) - shared by ReaderView
  /// and anything else (e.g. ReadingProgressLookup) that reads bookmarks
  /// for a document without opening it.
  static List<Bookmark> decodeList(String raw) {
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => Bookmark.fromJson(e as Map<String, dynamic>)).toList();
  }
}
