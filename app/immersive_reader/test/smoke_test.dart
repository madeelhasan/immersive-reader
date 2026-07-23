import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/parser_registry.dart';
import 'package:path/path.dart' as p;

void main() {
  test('TxtParser reads paragraphs and tokens from a real file', () async {
    final dir = Directory.systemTemp.createTempSync('ir_smoke');
    final file = File(p.join(dir.path, 'sample.txt'));
    file.writeAsStringSync('Hello world.\nThis is a second paragraph.');

    final parser = ParserRegistry.forFileName(file.path);
    final doc = await parser.parse(file);

    expect(doc.paragraphs, isNotEmpty);
    expect(doc.paragraphs.first.sentences.first.tokens.first.text, 'Hello');

    dir.deleteSync(recursive: true);
  });
}
