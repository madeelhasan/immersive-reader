# Task brief: finish Phase 1 of Immersive Reader

**Status: all four items below are now implemented** (scroll persistence, font size, theme toggle, EPUB chapter nav) — see `CLAUDE.md`'s "Delegating to other coding agents" section for how that actually went (local-model delegation failed 6/6 times; all four were implemented directly). Kept here as a reference for the design/dependency pitfalls hit along the way, in case similar work comes up in later phases.

Read `../../spec/SPEC.md` first — it is the source of truth for architecture decisions (section 2) and the Phase 1 scope/acceptance checklist (section 5). Everything below assumes you've read it.

## Current status

The parser pipeline (TXT/DOCX/EPUB/PDF -> `DocumentModel` -> `ReaderView`) already works end to end and is tested against real files in `test/fixtures/`. Do not rework `lib/parsers/`, `lib/models/`, or `lib/reader/reader_controller.dart`'s existing scroll-tracking unless a task below requires it.

Four Phase 1 acceptance-criteria items (SPEC.md section 5) were never implemented. That's the actual scope of this task:

1. **Adjustable font size** — no control exists anywhere in the UI.
2. **Light/dark theme toggle** — `main.dart` has one hardcoded `ThemeData`.
3. **Remembers last scroll position per document** — `ReaderController` (`lib/reader/reader_controller.dart`) tracks scroll position in memory only; nothing persists it across app restarts. `lib/storage/local_db.dart` defines the `word_progress` SQLite table from SPEC.md section 3.3, but that table is for Phase 3/4 vocabulary progress, not scroll position — don't repurpose it. Use `shared_preferences` (add as a new dependency) keyed by `document_id`, storing `{documentId: scrollPixels}`. This is simpler than SQLite for a single float per document and avoids growing `local_db.dart`'s scope.
4. **EPUB "chapters navigable"** — `lib/parsers/epub_parser.dart` currently parses chapters correctly but flattens them into one continuous paragraph list with no chapter boundaries retained, and there's no navigation UI (table of contents / jump-to-chapter).

## Constraints learned the hard way — read before adding dependencies or touching parsers

- **`xml` package version conflict.** `syncfusion_flutter_pdf` (used for PDF parsing) requires `xml ^7.x`. Packages like `epubx` and `docx_to_text` require `xml ^6.x` and are incompatible — that's why `lib/parsers/docx_parser.dart` and `lib/parsers/epub_parser.dart` parse DOCX/EPUB manually via the `archive` package instead of using those libraries. If you add any new dependency, run `flutter pub get` immediately and check for a similar transitive conflict before writing code against it.
- **Paragraph word cap.** `DocumentParser.buildParagraphs()` in `lib/parsers/parser_interface.dart` caps every paragraph at 300 words (`maxParagraphWords`). This exists because `ReaderView` previously tried to render an entire PDF as one `Wrap` of 133,000+ `Text` widgets, which hung the UI. When you add EPUB chapter boundaries, preserve this cap — track chapter boundaries as metadata (e.g., which paragraph indices belong to which chapter) rather than reverting to one paragraph per chapter.
- **`testWidgets()` + real file I/O.** If you write a widget test that parses a real file before pumping a widget, wrap the parse call in `tester.runAsync(() => ...)`. Awaiting real async I/O directly inside `testWidgets()`'s fake-async zone can hang forever — see `test/reader_view_fixture_test.dart` for the working pattern.
- **`document_model.dart` field names** (`document_id`, `paragraph_id`, `sentence_id`) are intentionally snake_case to mirror SPEC.md section 3.1's JSON shape exactly. Don't rename them to fix the `non_constant_identifier_names` lint info — that's a deliberate style tradeoff, already discussed and accepted.

## Relevant current signatures

`lib/reader/reader_controller.dart`:
```dart
class ReaderController extends ChangeNotifier {
  double get scrollPosition;
  int get positionIndex;
  void updateScrollPosition(double newPosition);
  void updatePositionIndex(int newIndex);
}
```

`lib/reader/reader_view.dart`: `ReaderView({document, controller})`, builds a `ListView.builder` over `document.paragraphs`, each paragraph rendered as a `Column` of `Wrap`s of `Text` widgets (one per token).

`lib/main.dart`: `ImmersiveReaderApp` (root `MaterialApp`) -> `HomePage` (open-file button via `file_picker`, shows `ReaderView` once a document is parsed).

`lib/models/document_model.dart`: `DocumentModel(document_id, title, paragraphs)`, `ParagraphModel(paragraph_id, sentences)`, `SentenceModel(sentence_id, tokens)`. No chapter concept exists yet — you'll need to add one for task 4 (e.g. an optional `chapterTitles: Map<int, String>` on `DocumentModel` mapping starting paragraph index -> chapter title, so it stays backward compatible for TXT/DOCX/PDF which have no chapters).

## Test fixtures

Real files to test against are in `test/fixtures/`: a novel-length PDF and a DOCX CV. Use these instead of only synthetic test data — that's what surfaced the paragraph-cap bug last time.

## Definition of done, per task

For each of the four items:
1. Implement it.
2. Run `flutter analyze` — must stay at 0 errors/warnings (a handful of pre-existing `info`-level style lints are fine and documented above).
3. Run `flutter test` — all existing tests must still pass; add new tests for the feature.
4. Run `flutter build windows --debug` — must succeed.

Don't move to the next item until the current one is clean on all four steps.
