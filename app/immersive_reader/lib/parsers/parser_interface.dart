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
  List<ParagraphModel> buildParagraphs(Iterable<String> blocks) {
    final paragraphs = <ParagraphModel>[];
    var position = 0;

    for (final block in blocks) {
      final words =
          block.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      for (var i = 0; i < words.length; i += maxParagraphWords) {
        final chunk =
            words.skip(i).take(maxParagraphWords).join(' ');
        final tokens = tokenize(chunk, startIndex: position);
        position += tokens.length;
        paragraphs.add(ParagraphModel(
          paragraph_id: '${paragraphs.length}',
          sentences: [
            SentenceModel(sentence_id: '${paragraphs.length}', tokens: tokens),
          ],
        ));
      }
    }

    return paragraphs;
  }
}
