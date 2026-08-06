// Shared HTML-to-text helpers used by both HtmlParser and EpubParser (EPUB
// chapters are themselves just XHTML - see epub_parser.dart's own doc
// comment). Deliberately regex-based, not a real HTML parser package - see
// SPEC.md section 5's library note for why (`package:html` was the
// suggested option; verify it doesn't reintroduce the `xml`-version
// conflict that ruled out `docx_to_text`/`epubx` before adding it).

/// Strips tags, whole `<head>`/`<script>`/`<style>` blocks (content and
/// all - a naive tag-only strip would otherwise leak JS/CSS source and
/// `<title>` text into the reader), and decodes the handful of HTML
/// entities that show up in real-world documents.
String stripHtml(String html) {
  final withoutHead = html.replaceAll(
    RegExp(r'<head\b[^>]*>.*?</head>', dotAll: true, caseSensitive: false),
    ' ',
  );
  final withoutScriptsAndStyles = withoutHead
      .replaceAll(
        RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true, caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true, caseSensitive: false),
        ' ',
      );
  final withoutTags = withoutScriptsAndStyles.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

/// Splits raw HTML into paragraph-sized text blocks using `</p>` boundaries,
/// falling back to `<br>` when there are no `<p>` tags at all, then further
/// splitting on blank lines and dropping anything that strips down to
/// nothing (e.g. a `<p>` that only ever contained whitespace).
List<String> splitHtmlIntoBlocks(String html) {
  final byParagraphTag = html.split(RegExp(r'</p\s*>', caseSensitive: false));
  final rawBlocks = byParagraphTag.length > 1
      ? byParagraphTag
      : html.split(RegExp(r'<br\s*/?>', caseSensitive: false));

  return rawBlocks
      .map(stripHtml)
      .expand((text) => text.split(RegExp(r'\r?\n\s*\r?\n')))
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .toList();
}
