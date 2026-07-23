// lib/tests/parser_registry_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/parser_registry.dart'
    as parser_registry;
import 'package:immersive_reader/parsers/txt_parser.dart';

void main() {
  group('ParserRegistry', () {
    test('returns a txt parser for .txt files', () {
      final parser = parser_registry.ParserRegistry.forFileName('notes.txt');
      expect(parser, isA<TxtParser>());
    });
  });
}
