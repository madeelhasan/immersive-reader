import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/document_model.dart';
import 'archive_safety.dart';
import 'html_text_utils.dart';
import 'parser_interface.dart';

/// EPUB is a zip of XHTML files. We parse it manually (rather than via the
/// `epubx` package) because epubx pins an `xml` version that conflicts with
/// `syncfusion_flutter_pdf`'s `xml` requirement - see SPEC.md section 5.
/// Tag-stripping/block-splitting is shared with HtmlParser via
/// html_text_utils.dart, since EPUB chapters are themselves just XHTML.
class EpubParser extends DocumentParser {
  @override
  Future<DocumentModel> parse(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final rawChapters = _readingOrderContent(archive);

    final paragraphs = <ParagraphModel>[];
    final chapterMarkers = <ChapterMarker>[];
    var position = 0;

    for (final rawChapter in rawChapters) {
      final blocks = splitHtmlIntoBlocks(rawChapter);
      if (blocks.isEmpty) continue;

      chapterMarkers.add(ChapterMarker(
        title: _extractChapterTitle(rawChapter) ?? 'Chapter ${chapterMarkers.length + 1}',
        paragraphIndex: paragraphs.length,
      ));

      final chapterParagraphs = buildParagraphs(
        blocks,
        startPosition: position,
        startParagraphId: paragraphs.length,
      );
      position += chapterParagraphs
          .expand((para) => para.sentences)
          .expand((sentence) => sentence.tokens)
          .length;
      paragraphs.addAll(chapterParagraphs);
    }

    return DocumentModel(
      document_id: p.basenameWithoutExtension(file.path),
      title: p.basenameWithoutExtension(file.path),
      paragraphs: paragraphs,
      chapters: chapterMarkers,
    );
  }

  /// Pulls a heading out of a chapter's raw HTML to use as its nav title.
  String? _extractChapterTitle(String html) {
    final match = RegExp(r'<h[12]\b[^>]*>(.*?)</h[12]>', dotAll: true, caseSensitive: false)
        .firstMatch(html);
    if (match == null) return null;
    final title = stripHtml(match.group(1)!).trim();
    return title.isEmpty ? null : title;
  }

  /// Resolves the EPUB's chapter files in spine order via
  /// META-INF/container.xml -> the OPF manifest/spine.
  /// Falls back to alphabetical XHTML files if anything is missing/malformed.
  List<String> _readingOrderContent(Archive archive) {
    final byName = {for (final f in archive.files) f.name: f};

    final container = byName['META-INF/container.xml'];
    if (container == null) return _fallbackChapters(archive);

    final opfPath = RegExp(r'full-path="([^"]+)"')
        .firstMatch(_decode(container))
        ?.group(1);
    final opfFile = opfPath == null ? null : byName[opfPath];
    if (opfFile == null) return _fallbackChapters(archive);

    final opf = _decode(opfFile);
    final opfDir = p.dirname(opfPath!);

    final manifest = <String, String>{};
    for (final item in RegExp(r'<item\b[^>]*>').allMatches(opf)) {
      final tag = item.group(0)!;
      final id = RegExp(r'id="([^"]+)"').firstMatch(tag)?.group(1);
      final href = RegExp(r'href="([^"]+)"').firstMatch(tag)?.group(1);
      if (id != null && href != null) {
        manifest[id] = opfDir == '.' ? href : p.join(opfDir, href);
      }
    }

    final spineIds = RegExp(r'<itemref\b[^>]*idref="([^"]+)"')
        .allMatches(opf)
        .map((m) => m.group(1)!)
        .toList();

    final chapters = <String>[];
    for (final id in spineIds) {
      final href = manifest[id]?.replaceAll('\\', '/');
      final chapterFile = href == null ? null : byName[href];
      if (chapterFile != null) chapters.add(_decode(chapterFile));
    }

    return chapters.isEmpty ? _fallbackChapters(archive) : chapters;
  }

  List<String> _fallbackChapters(Archive archive) {
    final htmlFiles = archive.files
        .where((f) =>
            f.isFile &&
            RegExp(r'\.(x?html?)$', caseSensitive: false).hasMatch(f.name))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return htmlFiles.map(_decode).toList();
  }

  String _decode(ArchiveFile file) => decodeArchiveEntrySafely(file);
}
