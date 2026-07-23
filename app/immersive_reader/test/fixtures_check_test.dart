import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/parser_registry.dart';

void main() {
  final fixturesDir = Directory('test/fixtures');

  for (final file in fixturesDir.listSync().whereType<File>()) {
    if (file.path.endsWith('.md')) continue;

    test('parses ${file.path}', () async {
      final parser = ParserRegistry.forFileName(file.path);
      final doc = await parser.parse(file);

      final tokens = doc.paragraphs
          .expand((p) => p.sentences)
          .expand((s) => s.tokens)
          .toList();
      final snippet = tokens.take(25).map((t) => t.text).join(' ');

      print('--- ${file.path} ---');
      print('title: ${doc.title}');
      print('paragraphs: ${doc.paragraphs.length}, tokens: ${tokens.length}');
      print('snippet: $snippet');

      expect(tokens, isNotEmpty, reason: 'no text extracted from ${file.path}');
    });
  }
}
