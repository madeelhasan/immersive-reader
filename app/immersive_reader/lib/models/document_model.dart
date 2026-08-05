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
}

class ParagraphModel {
  final String paragraph_id;
  final List<SentenceModel> sentences;

  ParagraphModel({
    required this.paragraph_id,
    required this.sentences,
  });

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

  @override
  String toString() =>
      'SentenceModel(sentence_id: $sentence_id, tokens: $tokens)';
}
