# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter desktop app (`immersive_reader/`) that will eventually teach German through progressive word replacement while reading English documents. `../spec/SPEC.md` is the source of truth for product scope and locked architecture decisions (section 2) — read it before proposing architecture changes; the intro explicitly asks agents to "propose changes here first if something doesn't fit" rather than improvise.

Phase 1 (SPEC.md section 5) is functionally complete: a clean reflowed reader for TXT/DOCX/EPUB/PDF, adjustable font size, light/dark/system theme, persisted per-document scroll position, and EPUB chapter navigation. Phase 2 (SPEC.md section 6: "wire in the vocabulary dataset + tap-to-toggle UI + flat-rate random replacement, no adaptivity yet") is also functionally complete - a starter vocabulary dataset, an isolated `ReplacementEngine`, and tap-to-toggle rendering in `ReaderView` are all in place. The vocabulary dataset is a 100-entry A1-only placeholder, not the full ~1,500-2,000 entries across A1-B2 SPEC.md 3.2 calls for - expanding it is real remaining work, not done. Don't build toward Phases 3–5 (backend, SM-2 adaptive progress, mobile) yet.

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

**Phase 2's replacement pipeline is a straight line, deliberately not the adaptive algorithm from SPEC.md section 4.** `VocabularyRepository.load()` (`lib/vocabulary/`) reads `assets/vocab/en_de_starter.json` into a lowercase-English-keyed `Map<String, VocabularyEntry>`. `ReplacementEngine.selectReplacements()` (`lib/replacement/`, pure Dart, no Flutter imports, unit-tested with plain `Token`s per SPEC.md section 7) rolls a flat per-occurrence probability (default 15%) for each word token found in the vocabulary and returns a `tokenId -> German text` map — no depth scaling, no word-status weighting, since SPEC.md section 6 explicitly scopes Phase 2 to flat-rate only; the full section 4 algorithm is Phase 4. `main.dart`'s `HomePage` runs this once per opened document and passes the result into `ReaderView(replacements: ...)`. `ReaderView` renders any token present in that map as German (styled blue/underlined) unless its `tokenId` is in a local `_toggledToEnglish` set, which `GestureDetector.onTap` flips — toggling is per-occurrence, not per-word, matching SPEC.md section 1 exactly.

## Delegating to other coding agents

`immersive_reader/.aider.conf.yml` configures Aider to auto-run `flutter test`/`dart analyze` and self-correct before returning control, and `PROJECT_OVERVIEW.md`/`QWEN_TASK_BRIEF.md` are onboarding docs written for other agents. Local Ollama models (`qwen2.5-coder:7b`, `qwen3.6:latest`) failed 6/6 times on Phase 1 work — see git history around the Phase 1 completion commits for the detail. **Switching to a hosted model (DeepSeek's API, `deepseek/deepseek-chat`) fixed reliability**, but getting there required diagnosing three separate process bugs, all still relevant to any future delegation on this repo:

- **Aider interprets in-chat/instruction file paths relative to the *git working directory*, not wherever it's invoked from.** It says so in its own startup banner every time - easy to miss. This repo's git root is one level above `immersive_reader/`. Always give Aider paths prefixed with `app/immersive_reader/...`, never bare `lib/...`, or files land outside the Flutter project entirely (this happened twice before being caught).
- **Aider auto-detects chat language from the OS locale.** If the host machine's Windows locale isn't `en-*`, pin `chat-language: english` in `.aider.conf.yml` - otherwise Aider silently tells the model to reply in that locale's language, which measurably degrades output quality/consistency.
- **`lint-cmd`/`test-cmd` must be `flutter.bat analyze`/`flutter.bat test` with full paths, never bare `dart analyze`.** Aider invokes the lint command against a single edited file; `dart analyze <single-file>` (as opposed to `flutter analyze`, or `dart analyze` with no file argument) fails to resolve `package:flutter/...` imports for reasons specific to single-file targeting, and the model will get stuck trying to "fix" what's actually an unfixable shell/environment error - this produced a genuine repeated-output loop, not just a wrong answer.

With all three fixed, DeepSeek applied every subsequent edit correctly and cheaply (each Phase 2 module cost under a tenth of a cent). Multi-class UI restructuring (e.g. splitting a `StatelessWidget` into `StatefulWidget` + threading a callback across files, like the Phase 1 theme toggle) is still the one task class that's failed even with DeepSeek - that kind of change has consistently been implemented directly rather than delegated.
