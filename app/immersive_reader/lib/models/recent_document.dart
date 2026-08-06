/// An entry in the "recent documents" list shown on launch (SPEC.md section
/// 3.5/7) - enough to display and resume a previously-opened file without
/// re-parsing anything up front. [documentId] matches
/// `DocumentModel.document_id` (deterministically the file's basename, not
/// a fresh UUID per open - see each DocumentParser's use of
/// `basenameWithoutExtension`), so it lines up with the same key
/// ReaderView already uses to persist scroll position/bookmarks.
class RecentDocument {
  final String documentId;
  final String title;
  final String filePath;
  final String format;
  final DateTime lastOpenedAt;

  RecentDocument({
    required this.documentId,
    required this.title,
    required this.filePath,
    required this.format,
    required this.lastOpenedAt,
  });

  Map<String, dynamic> toJson() => {
        'document_id': documentId,
        'title': title,
        'file_path': filePath,
        'format': format,
        'last_opened_at': lastOpenedAt.toIso8601String(),
      };

  factory RecentDocument.fromJson(Map<String, dynamic> json) => RecentDocument(
        documentId: json['document_id'] as String,
        title: json['title'] as String,
        filePath: json['file_path'] as String,
        format: json['format'] as String,
        lastOpenedAt: DateTime.parse(json['last_opened_at'] as String),
      );
}
