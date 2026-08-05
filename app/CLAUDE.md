# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter desktop app (`immersive_reader/`) that will eventually teach German through progressive word replacement while reading English documents. `../spec/SPEC.md` is the source of truth for product scope and locked architecture decisions (section 2) — read it before proposing architecture changes; the intro explicitly asks agents to "propose changes here first if something doesn't fit" rather than improvise.

Phase 1 (SPEC.md section 5) is functionally complete: a clean reflowed reader for TXT/DOCX/EPUB/PDF, adjustable font size, light/dark/system theme, persisted per-document scroll position, and EPUB chapter navigation. No translation logic yet - don't build toward Phases 2–5 (vocabulary replacement, backend, SM-2 progress, mobile) yet.

## Commands

All commands run from `immersive_reader/`. `flutter` is not on PATH in this environment — use the full path `C:\src\flutter\bin\flutter.bat` (or `& "C:\src\flutter\bin\flutter.bat" <cmd>` in PowerShell).

```
flutter pub get
flutter analyze                          # must stay at 0 errors/warnings
flutter test                             # full suite
flutter test test/smoke_test.dart        # single test file
flutter build windows --debug
flutter run -d windows
```

A git pre-commit hook (`.git/hooks/pre-commit`, repo root) runs `flutter analyze` + `flutter test` automatically and blocks the commit on real errors (it parses analyzer output for `error -` lines specifically, since `flutter analyze`'s exit code also goes non-zero for info-level lints that are intentionally accepted — see below).

## Architecture

**Data flow:** `ParserRegistry.forFileName(path)` (`lib/parsers/parser_registry.dart`) picks a `DocumentParser` subclass by extension → `parser.parse(File)` returns a `DocumentModel` → `main.dart`'s `HomePage` hands that to `ReaderView(document, controller)` → rendered as a lazily-built `ListView.builder`.

**The 300-word paragraph cap is load-bearing.** Every parser ends by calling `DocumentParser.buildParagraphs(blocks)` (shared base class, `lib/parsers/parser_interface.dart`), which tokenizes each raw text block and caps paragraphs at `maxParagraphWords` (300). This exists because an earlier version dumped whole documents into one paragraph, and `ReaderView` tried to build a single `Wrap` of 130,000+ `Text` widgets in one `ListView` item, which hung the UI (looked like "no text" was extracted, but the real problem was rendering, not parsing). Any parser change must keep routing through `buildParagraphs`, not tokenize a whole document directly.

**DOCX/EPUB are parsed manually (unzip + regex over the XML), not via `docx_to_text`/`epubx`.** `syncfusion_flutter_pdf` (PDF text extraction) pins `xml ^7.x` transitively; `docx_to_text` and `epubx` both pin `xml ^6.x` — mutually incompatible in one dependency graph. Check for this class of transitive conflict (`flutter pub get` immediately) before adding any new package.

**Data model field naming is intentionally inconsistent.** `DocumentModel`/`ParagraphModel`/`SentenceModel` fields (`document_id`, `paragraph_id`, `sentence_id`) are snake_case to mirror SPEC.md section 3.1's JSON shape exactly; `Token` fields are camelCase (Dart convention). This is a deliberate, already-discussed tradeoff — don't "fix" the resulting `non_constant_identifier_names` lint infos.

**Widget tests that parse real files must use `tester.runAsync()`.** Awaiting real file I/O directly inside `testWidgets()`'s fake-async zone can hang indefinitely rather than erroring — see `test/reader_view_fixture_test.dart` for the working pattern.

**Real file fixtures live in `test/fixtures/`** (a novel-length PDF, a DOCX CV) and are exercised by `test/fixtures_check_test.dart` — prefer these over only synthetic test strings; that's what originally surfaced the paragraph-cap bug. The PDF/DOCX themselves are git-ignored (copyright/PII); only `test/fixtures/README.md` is tracked. There's no EPUB fixture on disk (none was supplied); `test/epub_chapter_test.dart` builds a minimal synthetic EPUB in-memory via the `archive` package instead.

**`DocumentModel.chapters` is optional chapter-boundary metadata, populated only by `epub_parser.dart`.** It's a `List<ChapterMarker>` (`{title, paragraphIndex}`, both in `document_model.dart`) mapping into `DocumentModel.paragraphs` — TXT/DOCX/PDF leave it empty (default `const []`). `ReaderView` only shows the chapter-nav button when it's non-empty, and jumps to a chapter by scroll-fraction approximation (`paragraphIndex / paragraphs.length`), not a pixel-exact position — deliberately, since paragraphs are capped at a fairly uniform size (see above) and exact per-item height tracking in a lazy `ListView.builder` wasn't worth the complexity for this. Chapter titles come from the first `<h1>`/`<h2>` found in each chapter's raw HTML, falling back to "Chapter N" — there's no NCX/nav.xhtml table-of-contents parsing.

## Delegating to other coding agents

`immersive_reader/.aider.conf.yml` configures Aider (running a local Ollama model) to auto-run `flutter test`/`dart analyze` and self-correct before returning control, and `PROJECT_OVERVIEW.md`/`QWEN_TASK_BRIEF.md` are onboarding docs written for other agents. In practice, on this machine (RTX 5060 Laptop, 8GB VRAM), delegating actual Phase 1 feature work to Aider + local `qwen2.5-coder:7b` or `qwen3.6:latest` failed 6/6 times — the models either produced plausible Dart code in a format Aider's diff/whole-file parser couldn't apply (SEARCH/REPLACE markers, invented files, `// ... existing code ...` placeholders), or in one case hallucinated an entire fake conversation turn. A 32k-context Modelfile variant didn't fix it either. All four remaining Phase 1 items (scroll persistence, font size, theme toggle, EPUB nav) ended up implemented directly instead. Don't assume local-model delegation works on this hardware without re-verifying; a hosted API for a stronger unquantized model is more likely to actually apply edits than another local attempt.
