# Immersive Reader — Technical Specification

**Project:** Cross-platform reading app that teaches German through progressive word replacement while reading English documents.
**This document is the source of truth for any coding agent (human or LLM) working on this project.** Every phase should be implemented against this spec — don't improvise architecture decisions; propose changes here first if something doesn't fit.

---

## 1. Product Summary

A book-reader app that:
- Opens TXT, DOCX, EPUB, and PDF files and displays them in a clean, reflowed reading view (not a visual facsimile of the original file).
- Lets the reader declare their current German proficiency (CEFR level A1–B2), which gates which vocabulary is eligible for replacement and how dense that replacement is (see section 4).
- Randomly replaces certain English words with their German equivalents as the user reads.
- Lets the user tap any translated word to toggle it back to English.
- Tracks per-word exposure and increases replacement frequency for words the user has "learned," and increases overall replacement density as the user progresses deeper into a document.
- Runs on Windows and macOS first (Phase 1–4), then Android/iOS (Phase 5), from a single Flutter codebase.

---

## 2. Architecture Decisions (locked — do not change without discussion)

| Decision | Choice | Why |
|---|---|---|
| Client framework | **Flutter** (Dart) | One codebase for desktop + mobile; strong desktop targets unlike React Native |
| Backend | **FastAPI** (Python) | Serves vocabulary dataset, handles auth, syncs progress |
| Local DB (client) | **SQLite** via `drift` package | Offline-first; syncs to backend later |
| Server DB | **SQLite → Postgres later** | Start minimal-cost; migrate only when user count demands it |
| Document formats | **TXT, DOCX, EPUB, PDF** | MOBI dropped (DRM complexity); EPUB is open/unencrypted |
| Rendering model | **Extract → common token model → custom reflow renderer** | PDFs/DOCX can't be edited word-by-word in their native visual layout; we render our own text stream instead |
| Hosting | Free-tier (Render/Fly.io/Railway) to start | Minimal cost requirement |
| Vocabulary source | Static curated CEFR-tagged EN→DE dataset (JSON), not live translation API calls | Offline-capable, fast, pedagogically consistent, zero per-word API cost |

---

## 3. Core Data Model

### 3.1 Document → Internal Representation

Every input format (TXT/DOCX/EPUB/PDF) is parsed into this common structure before rendering:

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

Start with ~1,500–2,000 entries across A1–B2. This can be bootstrapped once (offline, not at runtime) using an LLM or DeepL, then hand-reviewed — do not call a translation API per word during reading.

### 3.3 User Progress (local SQLite, synced to backend)

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
- `status` graduates via a simplified SM-2 schedule based on `ease_factor` and `exposures`.
- `user_id` is a UUID string, backed by a `users` table (`id`, `email`, `hashed_password`) on the Phase 3 backend — see `backend/app/models.py`. Not yet in this section since it's an auth implementation detail, not part of the vocabulary-progress domain model; documented here as a pointer so `word_progress.user_id`'s origin is traceable.

### 3.4 User Level Setting

The reader declares their current German level — one of `A1`, `A2`, `B1`, `B2` — via a UI control (Phase 2: a simple selector; not tied to any account system until Phase 3's backend exists). Stored as a single local preference (`SharedPreferences`, key `german_level`), not in the `word_progress` table above — it's a coarse, manually-set starting point, distinct from the per-word `status` progress `word_progress` tracks once Phase 4's adaptive engine exists. Defaults to `A1` for a new install. See section 4 for how it affects replacement.

---

## 4. Replacement Algorithm (Phase 2/4 logic — spec now, build later)

### 4.1 Level eligibility filter (Phase 2, built)

The reader's declared level (section 3.4) determines which vocabulary entries are even eligible for replacement, and the flat base rate applied to them:

- **Eligibility is cumulative**: a reader at level `N` sees replacements from every CEFR level at or below `N` — e.g. a `B1` reader gets `A1` + `A2` + `B1` words, never `B2`. This matches CEFR's own cumulative-curriculum design and keeps a beginner from being shown vocabulary far above them, while a `B2` reader still draws from the full dataset.
- **Base rate scales with level**: `A1: 10%`, `A2: 15%`, `B1: 20%`, `B2: 25%` (per-occurrence, independent rolls — same flat-rate mechanic as before, just level-parameterized instead of a single constant). Rationale: a more advanced reader is both drawing from a larger eligible pool and ready for denser replacement.
- Implemented in `ReplacementEngine.selectReplacements(tokens, vocabulary, germanLevel: ...)` — still a pure function, still fully isolated from the renderer, still no depth/word-status logic. `levelOrder`/`levelRates` live as constants on `ReplacementEngine`.

### 4.2 Depth and word-status multipliers (Phase 4, not built)

Two further multipliers combine with the level-eligible pool above to decide the probability a given eligible word is shown in German at token `position_index`, once Phase 4's SM-2 progress tracking exists:

1. **Depth multiplier** — increases linearly (or logarithmically) from a low base rate (~5%) at document start toward a ceiling (~40%) by document end. Configurable curve.
2. **Word-status multiplier** — `new`/`introduced` words use the depth multiplier as-is; `learned` words get a flat high probability (~80–90%) regardless of depth, so they show up consistently once mastered.

`final_probability = base_rate_from_depth * status_weight[word.status]` — this replaces the flat level-based rate from 4.1 as the per-word probability once Phase 4 lands; the level filter itself (which words are eligible at all) stays in place unchanged.

This logic lives in one isolated module (`replacement_engine`) so it's independently testable and tunable without touching the renderer.

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
    parser_interface.dart      // common interface all 4 implement
  /models
    document_model.dart        // matches section 3.1 JSON shape
    token.dart
  /reader
    reader_view.dart           // reflowed text rendering, pagination/scrolling
    reader_controller.dart     // scroll position, current position_index tracking
  /storage
    local_db.dart              // drift/SQLite setup (schema from 3.3, unused until Phase 3/4)
  main.dart
```

### Parser interface (all 4 formats implement this)

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

### Suggested libraries (verify current versions/maintenance status before committing)
- PDF text extraction: `syncfusion_flutter_pdf` or `pdf_text`
- DOCX parsing: `docx_to_text` or manual XML parsing (DOCX is a zip of XML — `archive` + `xml` packages can do it directly if no maintained package fits)
- EPUB parsing: `epubx` or manual zip/XHTML parsing (EPUB is also just zipped XHTML)

---

## 6. Later Phases (reference only — don't build yet)

- **Phase 2:** Wire in the vocabulary dataset + tap-to-toggle UI + flat-rate random replacement, gated by a reader-declared CEFR level (section 4.1) — no depth/word-status adaptivity yet.
- **Phase 3:** FastAPI backend — auth, vocabulary served from API, progress sync endpoint. Backend-side, all three exist (`backend/`); client-side, only vocabulary-fetching is wired up (`VocabularyRepository`, with bundled-JSON fallback) — the client doesn't register/login or sync progress yet, since that's tied to Phase 4's client-side progress tracking rather than Phase 3's server-side plumbing.
- **Phase 4:** Depth/word-status replacement multipliers from section 4.2, SM-2 progress tracking wired to real usage.
- **Phase 5:** Android/iOS builds, touch-target and mobile-layout polish.

---

## 7. Instructions for the Coding Agent

- Work **one module at a time**, starting with `parser_interface.dart` and `document_model.dart`, since every other module depends on them.
- Do not skip the acceptance criteria checklist in Section 5 — treat it as the definition of done for Phase 1.
- If a suggested library (Section 5) is unmaintained or doesn't work as expected, stop and report back rather than substituting silently — architecture decisions in Section 2 may need revisiting.
- Run `flutter test` and `flutter run -d windows` (or `-d macos`) after each module to catch integration issues early, rather than building all 4 parsers before testing any of them.
- Keep the replacement engine (Section 4) fully isolated from the renderer — it should be unit-testable with plain strings/tokens, no UI dependency.

---

## 8. Cost-Minimization Notes

- No paid translation API calls at runtime — vocabulary dataset is static and bundled/served once.
- Backend on free-tier hosting (Render/Fly.io/Railway) until real usage demands otherwise.
- SQLite over managed Postgres until scale requires it.
- If using an open-weight LLM to write this code: work in small, single-module tasks (per Section 7) rather than "build the whole app" — this keeps token usage per task low and success rate high regardless of which model/agent harness is used.
