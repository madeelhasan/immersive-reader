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
  throw UnimplementedError();
}

/// Splits raw HTML into paragraph-sized text blocks using `</p>` boundaries,
/// falling back to `<br>` when there are no `<p>` tags at all, then further
/// splitting on blank lines and dropping anything that strips down to
/// nothing (e.g. a `<p>` that only ever contained whitespace).
List<String> splitHtmlIntoBlocks(String html) {
  throw UnimplementedError();
}
