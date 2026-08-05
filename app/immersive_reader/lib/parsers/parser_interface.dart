import 'dart:io';
import '../models/document_model.dart';
import '../models/token.dart';

/// Abstract interface for document parsers.
///
/// All concrete document parsers should extend this class and implement the [parse] method.
abstract class DocumentParser {
  Future<DocumentModel> parse(File file);

  /// A paragraph larger than this forces ReaderView to build that many Text
  /// widgets into one Wrap at once, which can hang the UI on large source
  /// blocks (a whole PDF page, a whole EPUB chapter, ...). Every parser
  /// should route its raw text blocks through [buildParagraphs] instead of
  /// tokenizing an unbounded block directly.
  static const int maxParagraphWords = 300;

  /// Splits [text] into word tokens. [startIndex] lets callers keep
  /// position_index running across multiple paragraphs in the same document.
  List<Token> tokenize(String text, {int startIndex = 0}) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return List.generate(
      words.length,
      (i) => Token(
        tokenId: '${startIndex + i}-${words[i].hashCode}',
        text: words[i],
        isWord: true,
        positionIndex: startIndex + i,
      ),
    );
  }

  /// Turns raw text blocks (paragraphs, pages, chapters - whatever unit the
  /// source format naturally splits into) into [ParagraphModel]s, keeping
  /// position_index running across the whole document. Blocks longer than
  /// [maxParagraphWords] are further chunked so no single paragraph can
  /// blow up the reader view.
  ///
  /// [startPosition]/[startParagraphId] let a caller that builds paragraphs
  /// in multiple batches (e.g. one call per EPUB chapter) keep token
  /// position and paragraph numbering continuous across the whole document
  /// instead of resetting to 0 on every call.
  List<ParagraphModel> buildParagraphs(
    Iterable<String> blocks, {
    int startPosition = 0,
    int startParagraphId = 0,
  }) {
    final paragraphs = <ParagraphModel>[];
    var position = startPosition;

    for (final block in blocks) {
      final words =
          block.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      for (var i = 0; i < words.length; i += maxParagraphWords) {
        final chunk =
            words.skip(i).take(maxParagraphWords).join(' ');
        final tokens = tokenize(chunk, startIndex: position);
        position += tokens.length;
        final id = '${startParagraphId + paragraphs.length}';
        paragraphs.add(ParagraphModel(
          paragraph_id: id,
          sentences: [SentenceModel(sentence_id: id, tokens: tokens)],
        ));
      }
    }

    return paragraphs;
  }
}
