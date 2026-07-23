import 'dart:io';
import 'package:path/path.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/document_model.dart';
import 'parser_interface.dart';

class PdfParser extends DocumentParser {
  @override
  Future<DocumentModel> parse(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);

    final blocks = <String>[];
    for (var page = 0; page < document.pages.count; page++) {
      final pageText =
          extractor.extractText(startPageIndex: page, endPageIndex: page);
      blocks.addAll(
        pageText
            .split(RegExp(r'\r?\n\s*\r?\n'))
            .map((block) => block.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((block) => block.isNotEmpty),
      );
    }
    document.dispose();

    return DocumentModel(
      document_id: basenameWithoutExtension(file.path),
      title: basenameWithoutExtension(file.path),
      paragraphs: buildParagraphs(blocks),
    );
  }
}
