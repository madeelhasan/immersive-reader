import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/document_model.dart';
import 'html_text_utils.dart';
import 'parser_interface.dart';

/// Standalone HTML/.htm files - no zip container, no spine/chapters (that's
/// EPUB-specific), just one file's worth of markup. Shares its tag-stripping/
/// block-splitting logic with EpubParser via html_text_utils.dart, since
/// EPUB chapters are themselves just XHTML.
class HtmlParser extends DocumentParser {
  @override
  Future<DocumentModel> parse(File file) async {
    final raw = await file.readAsString();
    final blocks = splitHtmlIntoBlocks(raw);

    return DocumentModel(
      document_id: p.basenameWithoutExtension(file.path),
      title: p.basenameWithoutExtension(file.path),
      paragraphs: buildParagraphs(blocks),
    );
  }
}
