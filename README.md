# Immersive Reader

A cross-platform Flutter app that will eventually teach German through progressive word replacement while reading English documents. Opens TXT, DOCX, EPUB, and PDF files, extracts and reflows their text into a clean, paginated reading view. Full product spec and locked architecture decisions live in [`spec/SPEC.md`](spec/SPEC.md); the app itself is in [`app/immersive_reader/`](app/immersive_reader/).

This README doubles as a case study: this project was built primarily through AI coding agents (Claude Code, Qwen Code CLI, and Aider running a local model), with a human directing scope, reviewing output, and making architecture calls. The sections below document what that actually looked like in practice — including where it went wrong.

## Status

**Phase 1** (a working reflowed reader, no translation logic yet) is functionally complete: all four formats parse correctly, `flutter analyze` is clean, the full test suite passes against real fixture files, and it builds and runs on Windows. Four Phase 1 UI polish items are still open: adjustable font size, light/dark theme, persisted per-document scroll position, and EPUB chapter navigation. Phases 2–5 (vocabulary replacement, backend, spaced-repetition progress tracking, mobile) are intentionally not started — see `spec/SPEC.md` sections 5–6 for the phased scope.

## Architecture, briefly

Every input format is parsed into a common `DocumentModel` (document → paragraphs → sentences → tokens), which a single `ReaderView` renders regardless of source format. Parser details, the data flow, and the non-obvious constraints that shaped the code are documented in [`app/immersive_reader/PROJECT_OVERVIEW.md`](app/immersive_reader/PROJECT_OVERVIEW.md) and [`app/CLAUDE.md`](app/CLAUDE.md).

## Building this with AI agents: what actually happened

The point of documenting this isn't "AI wrote the app" — it's what the actual workflow looked like, including the failures, since that's the part most AI-coding writeups skip.

**Bugs found during the initial build-out.** An early pass at the parser layer had ended up with duplicate, incompatible `Token` and `DocumentParser` type definitions scattered across the codebase (multiple classes with the same name, different shapes), which produced 35 analyzer errors. Fixing it required actually tracing which definitions were live versus dead, not just silencing errors.

**A performance bug that looked like a parsing bug.** Opening a real ~130,000-word PDF appeared to "not extract any text" — the app just sat blank. The actual cause: the whole book was being tokenized into a single paragraph, and the reader view tried to build one `Wrap` containing 130,000+ individual `Text` widgets in a single frame, which hung the UI rather than erroring. The fix — capping paragraph size and routing every parser through one shared chunking function — was verified against the real file, not a synthetic test string, which is what surfaced the bug in the first place.

**A real dependency conflict, not a made-up one.** `syncfusion_flutter_pdf` (PDF text extraction) and the more "obvious" DOCX/EPUB libraries (`docx_to_text`, `epubx`) pin incompatible major versions of the `xml` package. Rather than forcing an override that silently breaks one side, DOCX/EPUB parsing was rewritten to unzip and regex the underlying XML directly — a case of the "recommended" library not being viable and the fallback approach (spec'd as an explicit alternative) being the correct call.

**Delegating to a second agent — and it broke the app.** To test whether cheaper local models could offload implementation work, Qwen (via Qwen Code CLI) was tasked with adding scroll-position persistence. Its output didn't compile: import paths that don't exist in Dart's package resolution (`package:x/lib/...`), a missing dependency it never added to `pubspec.yaml`, calls to functions that were never defined, and it silently deleted the working file-picker integration in the process. Catching this required actually reading the diff and running `flutter analyze`, not trusting a "done" report.

**A real Python packaging bug, diagnosed rather than worked around blindly.** Installing Aider (a second delegation path) failed identically in two different environments with a `BackendUnavailable: Cannot import 'setuptools.build_meta'` error. The actual cause: Python 3.14 was new enough that Aider's current release's `requires-python` metadata likely excludes it, so `pip`'s resolver silently fell back through the version history to a three-year-old release with hard-pinned, unbuildable dependencies — a subtle failure mode, not a broken package. The fix was a dedicated Python 3.11 virtual environment, which resolved the real, current version immediately.

**The working setup.** Aider now runs against a local Ollama model (`qwen2.5-coder`), configured via `.aider.conf.yml` to auto-run `flutter analyze`/`flutter test` and self-correct before returning control — so it iterates against real feedback instead of a single unverified shot. A git pre-commit hook enforces the same checks. Every task it's given is scoped to one Phase 1 item at a time, verified independently afterward, matching the process `spec/SPEC.md` itself specifies for agents working on this repo.

## Running it

```
cd app/immersive_reader
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

`flutter` needs to be on your PATH, or invoked by full path — see `app/CLAUDE.md` for details specific to this setup.
