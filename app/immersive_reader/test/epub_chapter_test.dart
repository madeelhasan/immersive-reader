import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/epub_parser.dart';
import 'package:path/path.dart' as p;

Archive _buildTestEpub() {
  final archive = Archive();

  void addFile(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addFile('META-INF/container.xml', '''
<?xml version="1.0"?>
<container>
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''');

  addFile('OEBPS/content.opf', '''
<?xml version="1.0"?>
<package>
  <manifest>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>
''');

  addFile('OEBPS/chapter1.xhtml', '''
<html><body>
<h1>The Beginning</h1>
<p>${List.filled(50, 'alpha').join(' ')}</p>
<p>${List.filled(50, 'beta').join(' ')}</p>
</body></html>
''');

  addFile('OEBPS/chapter2.xhtml', '''
<html><body>
<h1>The Middle</h1>
<p>${List.filled(50, 'gamma').join(' ')}</p>
</body></html>
''');

  return archive;
}

void main() {
  test('EpubParser extracts chapter markers in spine order', () async {
    final dir = Directory.systemTemp.createTempSync('ir_epub_test');
    final file = File(p.join(dir.path, 'sample.epub'));
    file.writeAsBytesSync(ZipEncoder().encode(_buildTestEpub())!);

    final doc = await EpubParser().parse(file);

    expect(doc.chapters.length, 2);
    expect(doc.chapters[0].title, 'The Beginning');
    expect(doc.chapters[0].paragraphIndex, 0);
    expect(doc.chapters[1].title, 'The Middle');
    expect(doc.chapters[1].paragraphIndex, greaterThan(0));

    // position_index must run continuously across chapters, not reset.
    final allTokens =
        doc.paragraphs.expand((para) => para.sentences).expand((s) => s.tokens).toList();
    for (var i = 0; i < allTokens.length; i++) {
      expect(allTokens[i].positionIndex, i);
    }

    dir.deleteSync(recursive: true);
  });
}
