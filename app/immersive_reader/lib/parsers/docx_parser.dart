import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/document_model.dart';
import 'parser_interface.dart';

/// DOCX is a zip of XML files. We parse word/document.xml manually (rather
/// than via the `docx_to_text` package) because that package pins an `xml`
/// version that conflicts with `syncfusion_flutter_pdf`'s `xml` requirement
/// - see SPEC.md section 5.
class DocxParser extends DocumentParser {
  @override
  Future<DocumentModel> parse(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = archive.files
        .firstWhere((f) => f.name == 'word/document.xml');
    final xml = utf8.decode(documentXml.content as List<int>);

    final blocks = _paragraphText(xml).where((line) => line.isNotEmpty);

    return DocumentModel(
      document_id: p.basenameWithoutExtension(file.path),
      title: p.basenameWithoutExtension(file.path),
      paragraphs: buildParagraphs(blocks),
    );
  }

  List<String> _paragraphText(String documentXml) {
    return RegExp(r'<w:p\b[^>]*>.*?</w:p>', dotAll: true)
        .allMatches(documentXml)
        .map((paragraph) {
      final text = RegExp(r'<w:t\b[^>]*>([^<]*)</w:t>')
          .allMatches(paragraph.group(0)!)
          .map((m) => m.group(1) ?? '')
          .join();
      return _decodeEntities(text).trim();
    }).toList();
  }

  String _decodeEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
