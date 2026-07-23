import 'dart:io';
import 'package:path/path.dart';

import '../models/document_model.dart';
import 'parser_interface.dart';

class TxtParser extends DocumentParser {
  @override
  Future<DocumentModel> parse(File file) async {
    final content = await file.readAsString();
    final blocks = content
        .split(RegExp(r'\r?\n\s*\r?\n'))
        .where((block) => block.trim().isNotEmpty);

    return DocumentModel(
      document_id: basenameWithoutExtension(file.path),
      title: basenameWithoutExtension(file.path),
      paragraphs: buildParagraphs(blocks),
    );
  }
}
