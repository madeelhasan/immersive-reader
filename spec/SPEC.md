# Immersive Reader — Technical Specification

**Project:** Cross-platform reading app that teaches German through progressive word replacement while reading English documents.
**This document is the source of truth for any coding agent (human or LLM) working on this project.** Every phase should be implemented against this spec — don't improvise architecture decisions; propose changes here first if something doesn't fit.

---

## 1. Product Summary

A book-reader app that:
- Opens TXT, DOCX, EPUB, PDF, and HTML files and displays them in a clean, reflowed reading view (not a visual facsimile of the original file).
- Lets the reader declare their current German proficiency (CEFR level A1–C2), which gates which vocabulary is eligible for replacement and how dense that replacement is (see section 4). Once every word eligible at the reader's current level has reached `learned` status, the level auto-advances one step (section 4.3) — the reader can still override it manually at any time.
- Randomly replaces certain English words with their German equivalents as the user reads.
- Lets the user tap any translated word to toggle it back to English.
- Tracks per-word exposure and increases replacement frequency for words the user has "learned," and increases overall replacement density as the user progresses deeper into a document.
- No accounts, no login, no sign-up — the app is fully local and anonymous, always. Progress and reading history live only on the device (section 3.3/3.5).
- On launch, shows the last few documents the reader had open, resumable with one tap, alongside the option to open a new file (section 7).
- Runs on Windows and macOS first (Phase 1–4), then Android/iOS (Phase 5), from a single Flutter codebase.

---

## 2. Architecture Decisions (locked — do not change without discussion)

| Decision | Choice | Why |
|---|---|---|
| Client framework | **Flutter** (Dart) | One codebase for desktop + mobile; strong desktop targets unlike React Native |
| Backend | **FastAPI** (Python) | Serves vocabulary dataset. Auth + progress-sync endpoints (`backend/app/routers/auth.py`, `progress.py`) exist from earlier work but are no longer part of the product direction as of this revision - the app has no accounts (section 1) - see section 6 |
| Local DB (client) | **SQLite** via `sqflite` package (+ `sqflite_common_ffi` for in-memory test databases) | Offline-first; syncs to backend later. Originally spec'd as `drift`; the Phase 1 skeleton was built directly against `sqflite` and it was never revisited - documenting the actual choice here rather than migrating for its own sake, since `sqflite` has been reliable and a swap now would be pure churn with no functional gain |
| Server DB | **SQLite → Postgres later** | Start minimal-cost; migrate only when user count demands it |
| Document formats | **TXT, DOCX, EPUB, PDF, HTML** | MOBI dropped (DRM complexity); EPUB is open/unencrypted; HTML added since it's the same "extract text, ignore visual layout" category as the rest - no new architecture, just another parser |
| Rendering model | **Extract → common token model → custom reflow renderer** | PDFs/DOCX can't be edited word-by-word in their native visual layout; we render our own text stream instead |
| Hosting | Free-tier (Render/Fly.io/Railway) to start | Minimal cost requirement |
| Vocabulary source | Static curated CEFR-tagged EN→DE dataset (JSON), not live translation API calls | Offline-capable, fast, pedagogically consistent, zero per-word API cost |

---

## 3. Core Data Model

### 3.1 Document → Internal Representation

Every input format (TXT/DOCX/EPUB/PDF/HTML) is parsed into this common structure before rendering:

```json
{
  "document_id": "uuid",
  "title": "string",
  "paragraphs": [
    {
      "paragraph_id": "uuid",
      "sentences": [
        {
          "sentence_id": "uuid",
          "tokens": [
            {
              "token_id": "uuid",
              "text": "example",
              "is_word": true,
              "position_index": 0
            }
          ]
        }
      ]
    }
  ]
}
```

- `is_word: false` covers punctuation/whitespace tokens, which are never translated.
- `position_index` is a running counter across the whole document — used to compute "depth into document" for replacement-frequency scaling.

### 3.2 Vocabulary Dataset (server-served, bundled locally as fallback)

```json
{
  "en": "house",
  "de": "Haus",
  "cefr_level": "A1",
  "part_of_speech": "noun"
}
```

Start with ~1,500–2,000 entries across A1–B2 (reached — see the app README's Status section for current counts); C1/C2 were added later as a smaller top-up on the same dataset, not held to the same per-level volume as A1–B2. This can be bootstrapped once (offline, not at runtime) using an LLM or DeepL, then hand-reviewed — do not call a translation API per word during reading.

### 3.3 User Progress (local SQLite, never synced — see the `user_id` note below)

```sql
CREATE TABLE word_progress (
  user_id TEXT,
  en_word TEXT,
  exposures INTEGER DEFAULT 0,
  times_toggled_back INTEGER DEFAULT 0,
  times_toggled_forward INTEGER DEFAULT 0,
  last_seen_at TIMESTAMP,
  ease_factor REAL DEFAULT 2.5,      -- SM-2 style
  interval_days REAL DEFAULT 1,
  status TEXT DEFAULT 'new',          -- new | introduced | reinforced | learned
  PRIMARY KEY (user_id, en_word)
);
```

- `times_toggled_back` (user reverts to English) signals difficulty → lowers ease_factor.
- `times_toggled_forward` (user re-triggers German, if that's exposed) signals confidence.
- `status` graduates via a simplified SM-2 schedule based on `ease_factor` and `exposures`. This was left unspecified ("simplified... based on...") until Phase 4 actually implemented it - the concrete rules, as built in `Sm2Scheduler.recordExposure()` (`lib/progress/sm2_scheduler.dart`), applied on every exposure event:
  - `exposures` always increments by 1, regardless of outcome.
  - Neutral exposure (word shown, not toggled): `ease_factor` unchanged; `interval_days` multiplies by the current `ease_factor`.
  - Toggled back to English (difficulty signal): `ease_factor -= 0.2`, floored at `1.3`; `interval_days` resets to `1`.
  - Toggled forward to German again (confidence signal): `ease_factor += 0.15`, ceilinged at `2.8`; `interval_days` multiplies by the new `ease_factor`.
  - `status` is fully recomputed from the new `exposures`/`ease_factor` every time (not incremented) - first match wins: `learned` if `exposures >= 6 && ease_factor >= 2.5`; `reinforced` if `exposures >= 3 && ease_factor >= 2.0`; `introduced` if `exposures >= 1`; otherwise `new`.
- `user_id` is a permanent device-local placeholder UUID (`getOrCreateLocalUserId()`, `lib/progress/local_user_id.dart` - `SharedPreferences` key `local_user_id`, generated once per install via `Random.secure()`, never changes afterward). **As of this revision, the app has no accounts and never will** (section 1) - this isn't a placeholder standing in for a future real account, it's the permanent identity scheme; `word_progress` is never synced anywhere and the `PRIMARY KEY (user_id, en_word)` shape above is a holdover from when sync was planned, not a real multi-user requirement. A `users` table with an unrelated `id`/`email`/`hashed_password` shape exists on the Phase 3 backend (`backend/app/models.py`) from earlier work — unused by the client, not part of the product direction (see section 6).

### 3.4 User Level Setting

The reader declares their current German level — one of `A1`, `A2`, `B1`, `B2`, `C1`, `C2` — via a UI control (Phase 2: a simple selector; not tied to any account system — the app doesn't have one, section 1). Stored as a single local preference (`SharedPreferences`, key `german_level`), not in the `word_progress` table above — it's a coarse, manually-set starting point, distinct from the per-word `status` progress `word_progress` tracks via Phase 4's adaptive engine. Defaults to `A1` for a new install. Can also change automatically (section 4.3), not just via this control. See section 4 for how the level affects replacement.

### 3.5 Recent Documents (Phase 3.5 — spec'd, not yet built)

```json
// New. SharedPreferences key 'recent_documents', JSON-encoded list, newest
// first, capped at ~8 entries (oldest dropped past the cap). Local-only -
// there's nowhere to sync it to, since the app has no accounts (section 1).
{
  "document_id": "my_book",
  "title": "My Book",
  "file_path": "C:/Users/.../my_book.epub",
  "format": "epub",
  "last_opened_at": "2026-08-06T21:00:00Z"
}
```

- `document_id` here is the same value already used to key scroll position (`scroll_position_<document_id>` in `reader_view.dart`) and bookmarks - it's deterministically the file's basename without extension (see each parser's `document_id: ...basenameWithoutExtension(file.path)`), not a fresh UUID per open, so re-opening the same file already resumes at the right position today. This section formalizes surfacing that as a visible "recent documents" list rather than requiring the reader to know to reopen the same file.

---

## 4. Replacement Algorithm (Phase 2/4 logic — both built)

### 4.1 Level eligibility filter (Phase 2, built)

The reader's declared level (section 3.4) determines which vocabulary entries are even eligible for replacement, and the flat base rate applied to them:

- **Eligibility is cumulative**: a reader at level `N` sees replacements from every CEFR level at or below `N` — e.g. a `B1` reader gets `A1` + `A2` + `B1` words, never `B2`/`C1`/`C2`. This matches CEFR's own cumulative-curriculum design and keeps a beginner from being shown vocabulary far above them, while a `C2` reader draws from the full dataset.
- **Base rate scales with level**: `A1: 10%`, `A2: 15%`, `B1: 20%`, `B2: 25%`, `C1: 30%`, `C2: 35%` (per-occurrence, independent rolls — same flat-rate mechanic as before, just level-parameterized instead of a single constant). Rationale: a more advanced reader is both drawing from a larger eligible pool and ready for denser replacement.
- Implemented in `ReplacementEngine.selectReplacements(tokens, vocabulary, germanLevel: ...)` — still a pure function, still fully isolated from the renderer, still no depth/word-status logic. `levelOrder`/`levelRates` live as constants on `ReplacementEngine`.

### 4.2 Depth and word-status multipliers (Phase 4, built)

Two further multipliers combine with the level-eligible pool above to decide the probability a given eligible word is shown in German at token `position_index`:

1. **Depth multiplier** — increases linearly from a base rate of `5%` at document start to a ceiling of `40%` by document end: `depthMultiplier(progress) = 0.05 + 0.35 * progress`, where `progress` is the token's `position_index` normalized to a `0.0-1.0` fraction across the document.
2. **Word-status multiplier** — `new`/`introduced` words use the depth multiplier as-is. `reinforced` words get a value halfway between the depth curve and the learned ceiling. `learned` words get a flat `85%` regardless of depth, so they show up consistently once mastered.

**This section originally specified `final_probability = base_rate_from_depth * status_weight[word.status]`. That formula doesn't work and was corrected during implementation**: multiplying a 5-40% depth rate by a constant per-status weight cannot hold flat at ~85% across that entire range, which is exactly what "regardless of depth" (bullet 2, above) requires. The actual rule, implemented as `ReplacementEngine.probabilityFor(status, progress)`:

```
depth = depthMultiplier(progress)
learned:              return 0.85                            # flat, ignores depth entirely
reinforced:           return depth + (0.85 - depth) * 0.5    # blended halfway to the ceiling
new / introduced:     return depth                           # depth as-is
```

Implemented as `ReplacementEngine.selectReplacementsWithProgress()` (`lib/replacement/replacement_engine.dart`) - a **second method added alongside** the original flat-rate `selectReplacements()` from section 4.1, not a hard replacement of it (both still exist; 4.1's eligibility filter — which words are eligible at all — is shared by both and stays unchanged). `HomePage` calls `selectReplacementsWithProgress` once the local progress repository (`WordProgressRepository`, backed by `LocalDb`) has finished its async initialization, falling back to the flat-rate `selectReplacements` otherwise (e.g. briefly at app startup, or wherever no progress data is available) - graceful degradation rather than a hard cutover, so nothing breaks waiting on progress data to become ready.

This logic lives in one isolated module (`replacement_engine`) so it's independently testable and tunable without touching the renderer.

### 4.3 Automatic level advancement

Once every vocabulary entry eligible at the reader's *current* declared level (section 4.1's cumulative pool — not just that level in isolation) has reached `learned` status (section 3.3), the declared level (section 3.4) automatically advances one step (`A1→A2→B1→B2→C1→C2`), with an on-screen notification so the change isn't silent. `C2` is the ceiling — nothing to advance to past it. This is a convenience default, not a lock: the reader can still change their level manually at any time via the existing selector, including back down, and a manual change doesn't get overridden by this logic afterward — it only fires again once *that* new level's pool is also fully learned.

Doesn't apply retroactively on its own at app startup for a reader who already meets the criteria from before this feature existed - it's evaluated when word-progress state changes (i.e. after an exposure/toggle updates a word to `learned`), not on a timer or on every launch.

---

## 5. Phase 1 Scope (build this first)

**Goal:** A working desktop app that opens all 4 formats and displays them in a smooth reflowed reader. No translation yet.

### Modules to build

```
/lib
  /parsers
    txt_parser.dart
    docx_parser.dart
    epub_parser.dart
    pdf_parser.dart
    html_parser.dart           // added post-Phase-1 (see acceptance criteria below) - built
    parser_interface.dart      // common interface all 5 implement
  /models
    document_model.dart        // matches section 3.1 JSON shape
    token.dart
  /reader
    reader_view.dart           // reflowed text rendering, pagination/scrolling
    reader_controller.dart     // scroll position, current position_index tracking
  /storage
    local_db.dart              // sqflite setup (schema from 3.3) - dead code until Phase 4 wired it up
  main.dart
```

### Parser interface (all 5 formats implement this)

```dart
abstract class DocumentParser {
  Future<DocumentModel> parse(File file);
}
```

### Acceptance criteria for Phase 1
- [ ] Open a `.txt` file and see it rendered in a clean, paginated/scrollable reader view
- [ ] Open a `.docx` file — paragraph breaks preserved, formatting (bold/italic) optional stretch goal, not required
- [ ] Open a `.epub` file — chapters navigable, text reflowed
- [ ] Open a `.pdf` file — text extracted and reflowed (accept some loss of original layout/images — this is expected and desired per the "clean reader" goal)
- [ ] Reader UI: adjustable font size, light/dark theme, remembers last scroll position per document
- [ ] No translation logic yet — pure reading experience
- [x] **Added after Phase 1 originally shipped, now built:** Open a `.html`/`.htm` file — text extracted and reflowed the same as the other formats, tags/scripts/styles/head stripped, routed through the shared `DocumentParser.buildParagraphs()` 300-word cap like every other parser (see the Architecture section of `CLAUDE.md` for why that cap is load-bearing). Implemented in `lib/parsers/html_parser.dart`, sharing its tag-stripping/block-splitting with `EpubParser` via `lib/parsers/html_text_utils.dart` — EPUB chapters are themselves just XHTML, so no separate implementation was needed there.

### Suggested libraries (verify current versions/maintenance status before committing)
- PDF text extraction: `syncfusion_flutter_pdf` or `pdf_text`
- DOCX parsing: `docx_to_text` or manual XML parsing (DOCX is a zip of XML — `archive` + `xml` packages can do it directly if no maintained package fits)
- EPUB parsing: `epubx` or manual zip/XHTML parsing (EPUB is also just zipped XHTML)
- HTML parsing: this originally suggested `package:html` (Dart's own html5 parser) as "the obvious fit," reasoning it wouldn't pin a conflicting `xml` version the way `docx_to_text`/`epubx` do. **Turned out not to need a new dependency at all**: `EpubParser` already had manual regex-based tag-stripping/block-splitting for its XHTML chapters (see 3.1's note that EPUB is also just zipped XHTML), and that logic works identically on a standalone HTML file — extracted into a shared `lib/parsers/html_text_utils.dart` both parsers now use, rather than adding `package:html` for something regex already handled.

---

## 6. Later Phases (status noted per phase — Phase 5 is still the one genuinely not started)

- **Phase 2 (built):** Vocabulary dataset + tap-to-toggle UI + flat-rate random replacement, gated by a reader-declared CEFR level (section 4.1) — no depth/word-status adaptivity, that's Phase 4.
- **Phase 3 (superseded by the no-accounts direction below):** FastAPI backend originally built auth + progress-sync endpoints alongside the vocabulary API — all three exist (`backend/`) and are tested. As of this revision the product has no accounts at all (section 1): the vocabulary API stays in active use (`VocabularyRepository`, with bundled-JSON fallback); the `/auth` and `/progress` endpoints, and their client-side counterparts `AuthService`/`ProgressSyncService` (`lib/auth/`, `lib/progress/progress_sync_service.dart` — also built and tested), are not wired into any UI and are not planned to be. Left in place rather than deleted since they're working, tested code that costs nothing sitting unused; revisit only if accounts come back into scope.
- **Phase 4 (built):** Depth/word-status replacement multipliers from section 4.2, and SM-2 progress tracking (`Sm2Scheduler`, `WordProgressRepository`, `LocalDb`) wired to real usage in `ReaderView`/`HomePage` — every replaced-word render and toggle updates real local progress, and that progress now actually drives replacement probability (see 4.2). Stays permanently local (see Phase 3, above, and section 3.3) — there's no backend to sync it to.
- **Phase 3.5 (not started):** A "recent documents" resume screen (section 3.5/7) — the one piece of the earlier, accounts-focused Phase 3.5 plan that survives this revision's no-accounts direction.
- **Phase 5 (not started):** Android/iOS builds, touch-target and mobile-layout polish.

---

## 7. Recent Documents & Resume (Phase 3.5 — spec'd, not yet built)

Data model for this section is in 3.5; this section is the actual flow/UX. This is now the entirety of Phase 3.5 — the accounts/social-login/sign-out/forgot-password plan formerly spec'd here was dropped along with accounts generally (section 1); see section 6 for what that leaves behind.

On launch, instead of landing directly on "open a file" (today's behavior — see `HomePage`'s empty state), show up to ~8 most-recently-opened documents (title, last-opened time; reading-progress percentage is a nice-to-have derivable from `ReaderController`'s persisted scroll position but not required for v1), each tappable to reopen that exact file at its already-persisted scroll position — this reuses the existing `document_id`-keyed scroll-position/bookmark mechanism as-is (section 3.5 explains why no new plumbing is needed there). The existing "open another file" action (file-picker icon) stays available alongside the list, not replaced by it.

This list is local-only (SharedPreferences, section 3.5), which now needs no special justification — the app has no accounts and nothing to sync it to (section 1) — it stores local filesystem paths that wouldn't mean anything on another device regardless.

Must handle a listed file having since been moved/deleted without crashing — skip it or surface an inline "file not found" state on tap, don't let a stale path take down the home screen.

---

## 8. Instructions for the Coding Agent

- Work **one module at a time**, starting with `parser_interface.dart` and `document_model.dart`, since every other module depends on them.
- Do not skip the acceptance criteria checklist in Section 5 — treat it as the definition of done for Phase 1.
- If a suggested library (Section 5) is unmaintained or doesn't work as expected, stop and report back rather than substituting silently — architecture decisions in Section 2 may need revisiting.
- Run `flutter test` and `flutter run -d windows` (or `-d macos`) after each module to catch integration issues early, rather than building all 4 parsers before testing any of them.
- Keep the replacement engine (Section 4) fully isolated from the renderer — it should be unit-testable with plain strings/tokens, no UI dependency.

---

## 9. Cost-Minimization Notes

- No paid translation API calls at runtime — vocabulary dataset is static and bundled/served once.
- Backend on free-tier hosting (Render/Fly.io/Railway) until real usage demands otherwise.
- SQLite over managed Postgres until scale requires it.
- If using an open-weight LLM to write this code: work in small, single-module tasks (per Section 8) rather than "build the whole app" — this keeps token usage per task low and success rate high regardless of which model/agent harness is used.
