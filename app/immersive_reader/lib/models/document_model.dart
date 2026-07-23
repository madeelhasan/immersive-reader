// lib/models/document_model.dart
import 'token.dart';

class DocumentModel {
  final String document_id;
  final String title;
  final List<ParagraphModel> paragraphs;

  DocumentModel({
    required this.document_id,
    required this.title,
    required this.paragraphs,
  });

  @override
  String toString() =>
      'DocumentModel(document_id: $document_id, title: $title, paragraphs: $paragraphs)';
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
