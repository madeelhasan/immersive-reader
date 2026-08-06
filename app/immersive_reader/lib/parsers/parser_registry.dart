import 'package:path/path.dart' as p;

import 'docx_parser.dart';
import 'epub_parser.dart';
import 'html_parser.dart';
import 'parser_interface.dart';
import 'pdf_parser.dart';
import 'txt_parser.dart';

class ParserRegistry {
  static DocumentParser forFileName(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.pdf':
        return PdfParser();
      case '.docx':
        return DocxParser();
      case '.epub':
        return EpubParser();
      case '.txt':
        return TxtParser();
      case '.html':
      case '.htm':
        return HtmlParser();
      default:
        throw Exception('Unsupported file type: $fileName');
    }
  }
}
