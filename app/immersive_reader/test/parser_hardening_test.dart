// Regression tests for hostile/malformed DOCX and EPUB input, written after
// a security pass turned up a real issue: a small .docx whose
// word/document.xml decompresses to ~100MB (trivial to build with ordinary
// DEFLATE on repeated text - no nested-zip tricks needed) took 11+ seconds
// and ~100MB of memory to parse, since nothing capped decompressed entry
// size before decoding it. Fixed via archive_safety.dart's
// decodeArchiveEntrySafely, which checks ArchiveFile.size (the zip's
// declared *uncompressed* size, known before decompression) up front.
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/parsers/archive_safety.dart';
import 'package:immersive_reader/parsers/docx_parser.dart';
import 'package:immersive_reader/parsers/epub_parser.dart';

void main() {
  group('decodeArchiveEntrySafely', () {
    test('rejects an entry whose declared size exceeds the cap, without decompressing it', () {
      // ArchiveFile.noCompress lets the declared size and actual content
      // diverge, the same shape a hostile zip's central directory could
      // have - the point is this must be caught from `.size` alone, fast,
      // not by actually decompressing gigabytes to find out.
      final oversized = ArchiveFile.noCompress(
        'word/document.xml',
        maxDecompressedEntryBytes + 1,
        <int>[1, 2, 3],
      );

      expect(
        () => decodeArchiveEntrySafely(oversized),
        throwsA(isA<ArchiveEntryTooLargeException>()),
      );
    });

    test('allows an entry at or under the cap through', () {
      final content = Uint8List.fromList('hello'.codeUnits);
      final normal = ArchiveFile.noCompress('word/document.xml', content.length, content);
      expect(decodeArchiveEntrySafely(normal), 'hello');
    });
  });

  group('DocxParser hardening', () {
    test('a document.xml that would decompress far past the cap is rejected quickly, not decompressed', () async {
      final dir = await Directory.systemTemp.createTemp('ir_docx_bomb_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final archive = Archive();
      final bigParagraph = '<w:p><w:r><w:t>${'A' * 20 * 1000 * 1000}</w:t></w:r></w:p>';
      final xml = '<xml>${bigParagraph * 5}</xml>'; // ~100MB uncompressed, ~400KB on disk
      archive.addFile(ArchiveFile.string('word/document.xml', xml));
      final bytes = ZipEncoder().encode(archive)!;
      final file = File('${dir.path}/zipbomb.docx');
      await file.writeAsBytes(bytes);

      final sw = Stopwatch()..start();
      await expectLater(
        DocxParser().parse(file),
        throwsA(isA<ArchiveEntryTooLargeException>()),
      );
      // The old, unguarded code took 11+ seconds to actually decompress and
      // scan ~100MB; the guard should reject it near-instantly instead.
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('a .docx missing word/document.xml entirely throws a catchable error, not a crash', () async {
      final dir = await Directory.systemTemp.createTemp('ir_docx_malformed_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final archive = Archive();
      archive.addFile(ArchiveFile.string('not_the_right_file.txt', 'hello'));
      final bytes = ZipEncoder().encode(archive)!;
      final file = File('${dir.path}/malformed.docx');
      await file.writeAsBytes(bytes);

      expect(DocxParser().parse(file), throwsA(anything));
    });
  });

  group('EpubParser hardening', () {
    test('a manifest href containing ../ segments cannot escape the archive to read other files', () async {
      final dir = await Directory.systemTemp.createTemp('ir_epub_traversal_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final archive = Archive();
      archive.addFile(ArchiveFile.string(
        'META-INF/container.xml',
        '<container><rootfiles><rootfile full-path="OEBFS/content.opf"/></rootfiles></container>',
      ));
      archive.addFile(ArchiveFile.string(
        'OEBFS/content.opf',
        '<package>'
            '<manifest><item id="c1" href="../../../../etc/passwd"/></manifest>'
            '<spine><itemref idref="c1"/></spine>'
            '</package>',
      ));
      final bytes = ZipEncoder().encode(archive)!;
      final file = File('${dir.path}/traversal.epub');
      await file.writeAsBytes(bytes);

      // The href resolves to a path that isn't any entry in this archive,
      // so the chapter is silently skipped (falls through to "no chapters
      // found") rather than resolving to a real filesystem path anywhere.
      final doc = await EpubParser().parse(file);
      expect(doc.paragraphs, isEmpty);
    });

    test('a chapter file that would decompress far past the cap is rejected, not decompressed', () async {
      final dir = await Directory.systemTemp.createTemp('ir_epub_bomb_test');
      addTearDown(() => dir.deleteSync(recursive: true));

      final archive = Archive();
      archive.addFile(ArchiveFile.string(
        'META-INF/container.xml',
        '<container><rootfiles><rootfile full-path="content.opf"/></rootfiles></container>',
      ));
      archive.addFile(ArchiveFile.string(
        'content.opf',
        '<package>'
            '<manifest><item id="c1" href="chapter1.xhtml"/></manifest>'
            '<spine><itemref idref="c1"/></spine>'
            '</package>',
      ));
      final bigHtml = '<p>${'A' * 60 * 1000 * 1000}</p>'; // ~60MB, over the cap
      archive.addFile(ArchiveFile.string('chapter1.xhtml', bigHtml));
      final bytes = ZipEncoder().encode(archive)!;
      final file = File('${dir.path}/bomb.epub');
      await file.writeAsBytes(bytes);

      final sw = Stopwatch()..start();
      await expectLater(
        EpubParser().parse(file),
        throwsA(isA<ArchiveEntryTooLargeException>()),
      );
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
