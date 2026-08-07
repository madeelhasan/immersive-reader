// lib/models/document_model.dart
import 'token.dart';

class DocumentModel {
  final String document_id;
  final String title;
  final List<ParagraphModel> paragraphs;
  final List<ChapterMarker> chapters;

  DocumentModel({
    required this.document_id,
    required this.title,
    required this.paragraphs,
    this.chapters = const [],
  });

  Map<String, dynamic> toJson() => {
        'document_id': document_id,
        'title': title,
        'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
        document_id: json['document_id'] as String,
        title: json['title'] as String,
        paragraphs: (json['paragraphs'] as List)
            .map((p) => ParagraphModel.fromJson(p as Map<String, dynamic>))
            .toList(),
        chapters: (json['chapters'] as List? ?? const [])
            .map((c) => ChapterMarker.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  String toString() =>
      'DocumentModel(document_id: $document_id, title: $title, paragraphs: $paragraphs)';
}

/// Marks where a chapter starts within DocumentModel.paragraphs. Only
/// populated by parsers whose source format actually has chapters (EPUB);
/// other formats leave DocumentModel.chapters empty.
class ChapterMarker {
  final String title;
  final int paragraphIndex;

  ChapterMarker({required this.title, required this.paragraphIndex});

  Map<String, dynamic> toJson() => {'title': title, 'paragraphIndex': paragraphIndex};

  factory ChapterMarker.fromJson(Map<String, dynamic> json) => ChapterMarker(
        title: json['title'] as String,
        paragraphIndex: json['paragraphIndex'] as int,
      );
}

class ParagraphModel {
  final String paragraph_id;
  final List<SentenceModel> sentences;

  ParagraphModel({
    required this.paragraph_id,
    required this.sentences,
  });

  Map<String, dynamic> toJson() => {
        'paragraph_id': paragraph_id,
        'sentences': sentences.map((s) => s.toJson()).toList(),
      };

  factory ParagraphModel.fromJson(Map<String, dynamic> json) => ParagraphModel(
        paragraph_id: json['paragraph_id'] as String,
        sentences: (json['sentences'] as List)
            .map((s) => SentenceModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  @override
  String toString() =>
      'ParagraphModel(paragraph_id: $paragraph_id, sentences: $sentences)';
}

class SentenceModel {
  final String sentence_id;
  final List<Token> tokens; // Use the central Token class

  SentenceModel({
    required this.sentence_id,
    required this.tokens,
  });

  Map<String, dynamic> toJson() => {
        'sentence_id': sentence_id,
        'tokens': tokens.map((t) => t.toJson()).toList(),
      };

  factory SentenceModel.fromJson(Map<String, dynamic> json) => SentenceModel(
        sentence_id: json['sentence_id'] as String,
        tokens: (json['tokens'] as List)
            .map((t) => Token.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  @override
  String toString() =>
      'SentenceModel(sentence_id: $sentence_id, tokens: $tokens)';
}
