// lib/tests/parser_registry_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/html_parser.dart';
import 'package:immersive_reader/parsers/parser_registry.dart'
    as parser_registry;
import 'package:immersive_reader/parsers/txt_parser.dart';

void main() {
  group('ParserRegistry', () {
    test('returns a txt parser for .txt files', () {
      final parser = parser_registry.ParserRegistry.forFileName('notes.txt');
      expect(parser, isA<TxtParser>());
    });

    test('returns an html parser for .html files', () {
      final parser = parser_registry.ParserRegistry.forFileName('page.html');
      expect(parser, isA<HtmlParser>());
    });

    test('returns an html parser for .htm files', () {
      final parser = parser_registry.ParserRegistry.forFileName('page.htm');
      expect(parser, isA<HtmlParser>());
    });

    test('is case-insensitive on extension', () {
      final parser = parser_registry.ParserRegistry.forFileName('PAGE.HTML');
      expect(parser, isA<HtmlParser>());
    });
  });
}
