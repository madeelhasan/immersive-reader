import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/html_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  test('HtmlParser extracts text, stripping tags/scripts/styles/head', () async {
    final dir = Directory.systemTemp.createTempSync('ir_html_test');
    final file = File(p.join(dir.path, 'sample.html'));
    await file.writeAsString('''
<!DOCTYPE html>
<html>
<head><title>Ignore Me</title><style>body { color: red; }</style></head>
<body>
<script>alert("no");</script>
<p>${List.filled(50, 'alpha').join(' ')}</p>
<p>${List.filled(50, 'beta').join(' ')}</p>
</body>
</html>
''');

    final doc = await HtmlParser().parse(file);

    expect(doc.document_id, 'sample');
    expect(doc.title, 'sample');
    expect(doc.paragraphs, isNotEmpty);

    final allText = doc.paragraphs
        .expand((para) => para.sentences)
        .expand((s) => s.tokens)
        .map((t) => t.text)
        .join(' ');
    expect(allText, contains('alpha'));
    expect(allText, contains('beta'));
    expect(allText, isNot(contains('Ignore')));
    expect(allText, isNot(contains('alert')));
    expect(allText, isNot(contains('color')));

    // position_index must run continuously across paragraphs.
    final allTokens =
        doc.paragraphs.expand((para) => para.sentences).expand((s) => s.tokens).toList();
    for (var i = 0; i < allTokens.length; i++) {
      expect(allTokens[i].positionIndex, i);
    }

    dir.deleteSync(recursive: true);
  });

  test('HtmlParser falls back to <br> splitting when there are no <p> tags', () async {
    final dir = Directory.systemTemp.createTempSync('ir_html_test2');
    final file = File(p.join(dir.path, 'sample2.html'));
    await file.writeAsString(
        '<html><body>${List.filled(20, 'gamma').join(' ')}<br>${List.filled(20, 'delta').join(' ')}</body></html>');

    final doc = await HtmlParser().parse(file);
    final allText = doc.paragraphs
        .expand((para) => para.sentences)
        .expand((s) => s.tokens)
        .map((t) => t.text)
        .join(' ');
    expect(allText, contains('gamma'));
    expect(allText, contains('delta'));

    dir.deleteSync(recursive: true);
  });

  test('HtmlParser has no chapter markers (unlike EPUB)', () async {
    final dir = Directory.systemTemp.createTempSync('ir_html_test3');
    final file = File(p.join(dir.path, 'sample3.html'));
    await file.writeAsString('<html><body><p>Just some text</p></body></html>');

    final doc = await HtmlParser().parse(file);
    expect(doc.chapters, isEmpty);

    dir.deleteSync(recursive: true);
  });
}
