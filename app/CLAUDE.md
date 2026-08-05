# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter desktop app (`immersive_reader/`) that will eventually teach German through progressive word replacement while reading English documents. `../spec/SPEC.md` is the source of truth for product scope and locked architecture decisions (section 2) — read it before proposing architecture changes; the intro explicitly asks agents to "propose changes here first if something doesn't fit" rather than improvise.

Currently on Phase 1 (SPEC.md section 5): a clean reflowed reader for TXT/DOCX/EPUB/PDF, no translation logic yet. The parser pipeline and reader view work end-to-end. Four Phase 1 checklist items are still unbuilt: adjustable font size, light/dark theme toggle, persisted per-document scroll position, and EPUB chapter navigation. Don't build toward Phases 2–5 (vocabulary replacement, backend, SM-2 progress, mobile) yet.

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

**Real file fixtures live in `test/fixtures/`** (a novel-length PDF, a DOCX CV) and are exercised by `test/fixtures_check_test.dart` — prefer these over only synthetic test strings; that's what originally surfaced the paragraph-cap bug. The PDF/DOCX themselves are git-ignored (copyright/PII); only `test/fixtures/README.md` is tracked.

## Delegating to other coding agents

This repo is also set up for delegating implementation work to Aider running a local Ollama model (to keep Claude token usage limited to planning/verification, not bulk edits):
- `immersive_reader/.aider.conf.yml` configures Aider to auto-run `flutter test`/`dart analyze` and self-correct before returning control.
- `immersive_reader/PROJECT_OVERVIEW.md` and `immersive_reader/QWEN_TASK_BRIEF.md` are onboarding/task documents written for other agents (Qwen Code CLI, Aider) — keep them up to date when architecture changes, since they're a different agent's only context, not just documentation for humans.
