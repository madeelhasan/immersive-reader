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
}
