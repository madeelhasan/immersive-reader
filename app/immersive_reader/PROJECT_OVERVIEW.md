# Immersive Reader — project overview

Flutter desktop app (Windows/macOS first) that will eventually teach German through progressive word replacement while reading English documents. Full product spec and locked architecture decisions live at `../../spec/SPEC.md` — read that first; this file just orients you in the actual code as it exists today.

## Where things stand

Phase 1 (SPEC.md section 5) is functionally complete: opens TXT/DOCX/EPUB/PDF, adjustable font size, light/dark/system theme, persisted per-document scroll position, and EPUB chapter navigation, no translation logic yet. The parser pipeline and reader view work end-to-end and are tested against real files. `QWEN_TASK_BRIEF.md` documents the design/dependency pitfalls hit while building the last four items, for reference if similar work comes up in later phases.

Phases 2–5 (vocabulary replacement, backend, SM-2 progress tracking, mobile) are out of scope — don't build toward them yet, per SPEC.md section 6.

## Directory structure

```
lib/
  main.dart                      # App entry point + HomePage (file-open UI, wires parser -> ReaderView)
  models/
    token.dart                   # Token(tokenId, text, isWord, positionIndex) — the one true Token type
    document_model.dart          # DocumentModel/ParagraphModel/SentenceModel — matches SPEC.md section 3.1
  parsers/
    parser_interface.dart        # abstract DocumentParser: parse(), tokenize(), buildParagraphs()
    parser_registry.dart         # ParserRegistry.forFileName(path) -> the right parser by extension
    txt_parser.dart               # splits on blank lines, then buildParagraphs()
    docx_parser.dart              # unzips + regex-extracts word/document.xml <w:p>/<w:t>, then buildParagraphs()
    epub_parser.dart              # unzips, resolves OPF spine reading order, splits on <p>/<br>, then buildParagraphs()
    pdf_parser.dart                # syncfusion_flutter_pdf text extraction per page, then buildParagraphs()
  reader/
    reader_controller.dart       # ChangeNotifier: scrollPosition, positionIndex (in-memory only)
    reader_view.dart              # ListView.builder over paragraphs; font size, scroll persistence
                                   # (SharedPreferences, debounced), and chapter-nav bottom sheet all live here
  storage/
    local_db.dart                 # sqflite word_progress table (SPEC.md section 3.3) — defined but NOT wired
                                   # into the app anywhere yet; it's Phase 3/4 vocabulary-progress storage,
                                   # not scroll-position storage
test/
  fixtures/                      # REAL files to test against, not just synthetic strings
    A Court of Thorns and Roses - PDF Room.pdf   # ~500-page novel, exercises the paragraph-cap logic
    Adeel_Hasan_CV_Lovehoney_AI_Enablement.docx  # short structured document
  parser_registry_test.dart      # ParserRegistry dispatches by extension
  smoke_test.dart                # TxtParser end-to-end against a real temp file
  pdf_smoke_test.dart             # PdfParser against a syncfusion-generated in-memory PDF
  fixtures_check_test.dart        # runs every file in test/fixtures/ through ParserRegistry, asserts non-empty
  reader_view_fixture_test.dart   # pumps ReaderView with the real PDF fixture, checks it renders without hanging
  epub_chapter_test.dart          # builds a synthetic EPUB in-memory, checks chapter markers + continuous position_index
  widget_test.dart                # ImmersiveReaderApp smoke test
```

## Data flow

`ParserRegistry.forFileName(path)` picks a `DocumentParser` subclass by extension -> `parser.parse(File)` returns a `DocumentModel` -> `main.dart`'s `HomePage` hands that to `ReaderView(document, controller)` -> `ReaderView` renders it as a lazily-built `ListView.builder`.

Every parser ends by calling the shared `DocumentParser.buildParagraphs(blocks)` (in `parser_interface.dart`), which tokenizes each raw text block and caps paragraphs at 300 words (`maxParagraphWords`). This cap is load-bearing: an earlier version dumped whole documents into one paragraph, which made `ReaderView` try to build a single `Wrap` of 130,000+ `Text` widgets and hang. Any future parser change must keep going through `buildParagraphs`, not tokenize a whole document directly.

## Data model (matches SPEC.md section 3.1)

```dart
DocumentModel(document_id, title, paragraphs: List<ParagraphModel>, chapters: List<ChapterMarker>)
ParagraphModel(paragraph_id, sentences: List<SentenceModel>)
SentenceModel(sentence_id, tokens: List<Token>)
Token(tokenId, text, isWord, positionIndex)
ChapterMarker(title, paragraphIndex)  // optional; only EpubParser populates this
```

Note the deliberate mix of styles: `DocumentModel`/`ParagraphModel`/`SentenceModel` fields are snake_case (`document_id`, etc.) to mirror the SPEC's JSON shape exactly; `Token`/`ChapterMarker` fields are camelCase (Dart convention). This was a conscious choice, not an oversight — don't "fix" it.

`chapters` defaults to `const []`, so TXT/DOCX/PDF parsers are unaffected. `EpubParser` builds it by calling `buildParagraphs()` once per chapter with `startPosition`/`startParagraphId` carried over from the previous chapter, so `position_index` and paragraph numbering stay continuous across the whole document rather than resetting per chapter.

## Dependencies of note (`pubspec.yaml`)

- `syncfusion_flutter_pdf` — PDF text extraction. Pins `xml ^7.x` transitively, which is why DOCX/EPUB are parsed manually via `archive` instead of `docx_to_text`/`epubx` (both pin `xml ^6.x` — incompatible). Check for this class of conflict before adding any new package.
- `file_picker` — the "open file" dialog in `main.dart`.
- `sqflite`, `path_provider`, `path` — used by `local_db.dart` (currently unwired) and general path handling.
- `flutter_lints` (dev) — `analysis_options.yaml` references it; without it as a dependency the lint config silently no-ops.

## Build & test

Run from `immersive_reader/`:
```
flutter pub get
flutter analyze          # should be 0 errors/warnings (a few intentional info-level style lints are fine)
flutter test
flutter build windows --debug
flutter run -d windows   # actually launch it
```

## Known gotcha for writing new tests

If a test parses a real file inside `testWidgets(...)`, wrap the parse call in `tester.runAsync(() => ...)`. Awaiting real file I/O directly inside `testWidgets`'s fake-async zone can hang indefinitely — see `reader_view_fixture_test.dart` for the working pattern.
