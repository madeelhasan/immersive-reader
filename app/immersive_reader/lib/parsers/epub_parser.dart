import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/document_model.dart';
import 'parser_interface.dart';

/// EPUB is a zip of XHTML files. We parse it manually (rather than via the
/// `epubx` package) because epubx pins an `xml` version that conflicts with
/// `syncfusion_flutter_pdf`'s `xml` requirement - see SPEC.md section 5.
class EpubParser extends DocumentParser {
  @override
  Future<DocumentModel> parse(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final chapters = _readingOrderContent(archive);
    final blocks = chapters.expand(_splitIntoBlocks);

    return DocumentModel(
      document_id: p.basenameWithoutExtension(file.path),
      title: p.basenameWithoutExtension(file.path),
      paragraphs: buildParagraphs(blocks),
    );
  }

  /// Splits chapter HTML into paragraph-sized text blocks using <p>/<br>
  /// boundaries (falling back to blank-line breaks) before stripping tags,
  /// so a whole chapter doesn't become one oversized paragraph.
  List<String> _splitIntoBlocks(String html) {
    final byParagraphTag = html.split(RegExp(r'</p\s*>', caseSensitive: false));
    final rawBlocks = byParagraphTag.length > 1
        ? byParagraphTag
        : html.split(RegExp(r'<br\s*/?>', caseSensitive: false));

    return rawBlocks
        .map(_stripHtml)
        .expand((text) => text.split(RegExp(r'\r?\n\s*\r?\n')))
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
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

  String _decode(ArchiveFile file) => utf8.decode(file.content as List<int>);

  String _stripHtml(String html) {
    final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }
}
