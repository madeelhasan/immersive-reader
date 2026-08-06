import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/html_text_utils.dart';

/// Collapses all whitespace runs to a single space and trims - stripHtml's
/// exact spacing around removed tags isn't a real requirement (tokenize()
/// already splits on \s+), so tests normalize rather than assert on it.
String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  group('stripHtml', () {
    test('strips simple tags', () {
      expect(_norm(stripHtml('<p>Hello world</p>')), 'Hello world');
    });

    test('strips nested tags', () {
      expect(_norm(stripHtml('<p>Hello <b>bold</b> world</p>')), 'Hello bold world');
    });

    test('removes script blocks entirely, including their content', () {
      final result = stripHtml(
          '<p>Before</p><script>var x = 1; document.write("evil");</script><p>After</p>');
      expect(result, isNot(contains('evil')));
      expect(result, isNot(contains('var x')));
      expect(result, contains('Before'));
      expect(result, contains('After'));
    });

    test('removes style blocks entirely, including their content', () {
      final result = stripHtml('<style>body { color: red; }</style><p>Visible text</p>');
      expect(result, isNot(contains('color')));
      expect(result, contains('Visible text'));
    });

    test('removes head content entirely, including title', () {
      final result = stripHtml(
          '<html><head><title>Page Title</title><meta charset="utf-8"></head><body><p>Body text</p></body></html>');
      expect(result, isNot(contains('Page Title')));
      expect(result, contains('Body text'));
    });

    test('decodes common HTML entities', () {
      final result = stripHtml('<p>Tom &amp; Jerry &lt;3 &gt; 2 &nbsp; end</p>');
      expect(result, contains('Tom & Jerry'));
      expect(result, contains('<3'));
      expect(result, contains('> 2'));
    });

    test('is case-insensitive for script/style/head tag names', () {
      final result = stripHtml('<SCRIPT>bad()</SCRIPT><P>good text</P>');
      expect(result, isNot(contains('bad()')));
      expect(result, contains('good text'));
    });
  });

  group('splitHtmlIntoBlocks', () {
    test('splits on paragraph tags', () {
      final blocks = splitHtmlIntoBlocks('<p>First paragraph</p><p>Second paragraph</p>');
      expect(blocks, ['First paragraph', 'Second paragraph']);
    });

    test('falls back to <br> splitting when there are no <p> tags', () {
      final blocks = splitHtmlIntoBlocks('<div>Line one<br>Line two<br/>Line three</div>');
      expect(blocks, ['Line one', 'Line two', 'Line three']);
    });

    test('drops empty/whitespace-only blocks', () {
      final blocks = splitHtmlIntoBlocks('<p>Only content</p><p>   </p>');
      expect(blocks, ['Only content']);
    });
  });
}
