# Immersive Reader

A cross-platform Flutter app that will eventually teach German through progressive word replacement while reading English documents. Opens TXT, DOCX, EPUB, and PDF files, extracts and reflows their text into a clean, paginated reading view. Full product spec and locked architecture decisions live in [`spec/SPEC.md`](spec/SPEC.md); the app itself is in [`app/immersive_reader/`](app/immersive_reader/).

This README doubles as a case study: this project was built primarily through AI coding agents (Claude Code, Qwen Code CLI, and Aider running a local model), with a human directing scope, reviewing output, and making architecture calls. The sections below document what that actually looked like in practice — including where it went wrong.

## Status

**Phase 1** (a working reflowed reader, no translation logic yet) is complete: all four formats parse correctly, adjustable font size, light/dark/system theme, persisted per-document scroll position, and EPUB chapter navigation are all implemented and verified, `flutter analyze` is clean, the full test suite passes against real fixture files, and it builds and runs on Windows. Phases 2–5 (vocabulary replacement, backend, spaced-repetition progress tracking, mobile) are the current frontier — see `spec/SPEC.md` sections 5–6 for the phased scope.

## Architecture, briefly

Every input format is parsed into a common `DocumentModel` (document → paragraphs → sentences → tokens), which a single `ReaderView` renders regardless of source format. Parser details, the data flow, and the non-obvious constraints that shaped the code are documented in [`app/immersive_reader/PROJECT_OVERVIEW.md`](app/immersive_reader/PROJECT_OVERVIEW.md) and [`app/CLAUDE.md`](app/CLAUDE.md).

## Building this with AI agents: what actually happened

The point of documenting this isn't "AI wrote the app" — it's what the actual workflow looked like, including the failures, since that's the part most AI-coding writeups skip.

**Bugs found during the initial build-out.** An early pass at the parser layer had ended up with duplicate, incompatible `Token` and `DocumentParser` type definitions scattered across the codebase (multiple classes with the same name, different shapes), which produced 35 analyzer errors. Fixing it required actually tracing which definitions were live versus dead, not just silencing errors.

**A performance bug that looked like a parsing bug.** Opening a real ~130,000-word PDF appeared to "not extract any text" — the app just sat blank. The actual cause: the whole book was being tokenized into a single paragraph, and the reader view tried to build one `Wrap` containing 130,000+ individual `Text` widgets in a single frame, which hung the UI rather than erroring. The fix — capping paragraph size and routing every parser through one shared chunking function — was verified against the real file, not a synthetic test string, which is what surfaced the bug in the first place.

**A real dependency conflict, not a made-up one.** `syncfusion_flutter_pdf` (PDF text extraction) and the more "obvious" DOCX/EPUB libraries (`docx_to_text`, `epubx`) pin incompatible major versions of the `xml` package. Rather than forcing an override that silently breaks one side, DOCX/EPUB parsing was rewritten to unzip and regex the underlying XML directly — a case of the "recommended" library not being viable and the fallback approach (spec'd as an explicit alternative) being the correct call.

**Delegating to a second agent — and it broke the app.** To test whether cheaper local models could offload implementation work, Qwen (via Qwen Code CLI) was tasked with adding scroll-position persistence. Its output didn't compile: import paths that don't exist in Dart's package resolution (`package:x/lib/...`), a missing dependency it never added to `pubspec.yaml`, calls to functions that were never defined, and it silently deleted the working file-picker integration in the process. Catching this required actually reading the diff and running `flutter analyze`, not trusting a "done" report.

**A real Python packaging bug, diagnosed rather than worked around blindly.** Installing Aider (a second delegation path) failed identically in two different environments with a `BackendUnavailable: Cannot import 'setuptools.build_meta'` error. The actual cause: Python 3.14 was new enough that Aider's current release's `requires-python` metadata likely excludes it, so `pip`'s resolver silently fell back through the version history to a three-year-old release with hard-pinned, unbuildable dependencies — a subtle failure mode, not a broken package. The fix was a dedicated Python 3.11 virtual environment, which resolved the real, current version immediately.

**Local models weren't actually reliable, even after fixing the obvious problems.** Aider was pointed at `qwen2.5-coder:7b` via Ollama, and asked to add scroll-position persistence, then font size, then a theme toggle. All four attempts produced plausible-looking Dart code in the chat response — and none of it ever applied, because the model couldn't reliably follow Aider's machine-parseable edit format (SEARCH/REPLACE diff, unified diff, or whole-file), regardless of which format was requested. A theory that Ollama's default context window (2048 tokens, silently truncating anything longer with no error) was the cause led to baking a 32k-context variant via a custom Modelfile — it didn't fix it; that attempt produced an even more incoherent diff (an invented file that doesn't exist, a duplicated method definition, `// ... existing code ...` placeholders that aren't valid Dart). A much larger model (`qwen3.6:latest`, 23GB) was tried next and failed differently and worse: it hallucinated an entire fake conversation turn — inventing a message that was never sent — and never attempted the actual task. Six attempts, two models, zero successful applies. The likely root cause: this laptop's 8GB VRAM can't fit these models without quantization or CPU offload, and format-following degrades disproportionately under that kind of compression compared to raw code quality — the ideas were usually reasonable, the structured-output discipline wasn't there. All four Phase 1 UI items ended up implemented directly after the delegation attempts failed.

## The three-layer AI setup

This is the part worth explaining on its own, since it's the actual mechanism, not just an incident log:

1. **Claude Code (this session)** is the orchestrator. It holds context across the whole project, makes scope/architecture calls, writes precise task briefs for other agents, and — critically — independently re-verifies every delegated result (`flutter analyze`/`flutter test`/`flutter build`, reading the actual diff, checking `git status` to confirm something really changed) before anything counts as done. When delegation fails, it implements the fix directly rather than shipping broken or absent output. This is the expensive-per-token layer, used for judgment, not bulk typing.
2. **Aider** is the delegation harness — the thing that turns a model's response into an actual file edit, test run, and commit. It's model-agnostic: same tool, different backend swapped in via `--model provider/name`. `.aider.conf.yml` configures it to auto-run `flutter test`/`dart analyze` and self-correct before returning control, so it's not a single unverified shot. It runs from a dedicated Python 3.11 virtual environment (`aider-venv`), because the system's Python 3.14 was too new for `aider-chat`'s dependency resolution on PyPI — pip's resolver was silently falling back to a three-year-old release instead of the current one (see above).
3. **The model behind Aider** is the swappable part, and the one that actually matters for reliability. Local Ollama models were free but not reliable enough on this hardware (see above). The current setup uses **DeepSeek's hosted API** (`deepseek/deepseek-chat`) instead — pay-as-you-go, no subscription, roughly $0.14–0.28 per million tokens, serving the full unquantized model rather than a laptop-squeezed local copy. New accounts get free trial credits; testing it cost nothing beyond a small top-up once those ran out.

Two independent safety nets sit underneath all of this regardless of which model is behind Aider: Aider's own auto-test/auto-lint loop, and a **git pre-commit hook** that re-runs `flutter analyze`/`flutter test` before allowing any commit at all — so even a misconfigured or skipped self-correction loop can't get broken code into the repo. `app/CLAUDE.md` keeps an honest record of what's actually been tried and what failed, so a future session doesn't re-run the same experiment blind.

## Running it

```
cd app/immersive_reader
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

`flutter` needs to be on your PATH, or invoked by full path — see `app/CLAUDE.md` for details specific to this setup.
