# Immersive Reader — Technical Specification

**Project:** Cross-platform reading app that teaches German through progressive word replacement while reading English documents.
**This document is the source of truth for any coding agent (human or LLM) working on this project.** Every phase should be implemented against this spec — don't improvise architecture decisions; propose changes here first if something doesn't fit.

---

## 1. Product Summary

A book-reader app that:
- Opens TXT, DOCX, EPUB, PDF, and HTML files and displays them in a clean, reflowed reading view (not a visual facsimile of the original file).
- Lets the reader declare their current German proficiency (CEFR level A1–B2), which gates which vocabulary is eligible for replacement and how dense that replacement is (see section 4).
- Randomly replaces certain English words with their German equivalents as the user reads.
- Lets the user tap any translated word to toggle it back to English.
- Tracks per-word exposure and increases replacement frequency for words the user has "learned," and increases overall replacement density as the user progresses deeper into a document.
- Lets the reader register/sign in (email+password, or social login via Google/Facebook/Twitter) to sync progress across devices, and sign out again; works fully offline/anonymously if they never do (see section 7).
- On launch, shows the last few documents the reader had open, resumable with one tap, alongside the option to open a new file (section 7).
- Runs on Windows and macOS first (Phase 1–4), then Android/iOS (Phase 5), from a single Flutter codebase.

---

## 2. Architecture Decisions (locked — do not change without discussion)

| Decision | Choice | Why |
|---|---|---|
| Client framework | **Flutter** (Dart) | One codebase for desktop + mobile; strong desktop targets unlike React Native |
| Backend | **FastAPI** (Python) | Serves vocabulary dataset, handles auth, syncs progress |
| Local DB (client) | **SQLite** via `sqflite` package (+ `sqflite_common_ffi` for in-memory test databases) | Offline-first; syncs to backend later. Originally spec'd as `drift`; the Phase 1 skeleton was built directly against `sqflite` and it was never revisited - documenting the actual choice here rather than migrating for its own sake, since `sqflite` has been reliable and a swap now would be pure churn with no functional gain |
| Server DB | **SQLite → Postgres later** | Start minimal-cost; migrate only when user count demands it |
| Document formats | **TXT, DOCX, EPUB, PDF, HTML** | MOBI dropped (DRM complexity); EPUB is open/unencrypted; HTML added since it's the same "extract text, ignore visual layout" category as the rest - no new architecture, just another parser |
| Rendering model | **Extract → common token model → custom reflow renderer** | PDFs/DOCX can't be edited word-by-word in their native visual layout; we render our own text stream instead |
| Hosting | Free-tier (Render/Fly.io/Railway) to start | Minimal cost requirement |
| Vocabulary source | Static curated CEFR-tagged EN→DE dataset (JSON), not live translation API calls | Offline-capable, fast, pedagogically consistent, zero per-word API cost |
| Desktop OAuth flow | System browser + local loopback redirect (RFC 8252 Authorization Code + PKCE), backend brokers the token exchange | Flutter desktop has no first-party Google/Facebook/Twitter SDK the way mobile does; provider client secrets must stay server-side, not in a distributable desktop binary - see section 7 |

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
- `status` graduates via a simplified SM-2 schedule based on `ease_factor` and `exposures`. This was left unspecified ("simplified... based on...") until Phase 4 actually implemented it - the concrete rules, as built in `Sm2Scheduler.recordExposure()` (`lib/progress/sm2_scheduler.dart`), applied on every exposure event:
  - `exposures` always increments by 1, regardless of outcome.
  - Neutral exposure (word shown, not toggled): `ease_factor` unchanged; `interval_days` multiplies by the current `ease_factor`.
  - Toggled back to English (difficulty signal): `ease_factor -= 0.2`, floored at `1.3`; `interval_days` resets to `1`.
  - Toggled forward to German again (confidence signal): `ease_factor += 0.15`, ceilinged at `2.8`; `interval_days` multiplies by the new `ease_factor`.
  - `status` is fully recomputed from the new `exposures`/`ease_factor` every time (not incremented) - first match wins: `learned` if `exposures >= 6 && ease_factor >= 2.5`; `reinforced` if `exposures >= 3 && ease_factor >= 2.0`; `introduced` if `exposures >= 1`; otherwise `new`.
- `user_id` is a UUID string, backed by a `users` table (`id`, `email`, `hashed_password`) on the Phase 3 backend — see `backend/app/models.py`. Not yet in this section since it's an auth implementation detail, not part of the vocabulary-progress domain model; documented here as a pointer so `word_progress.user_id`'s origin is traceable. **Before Phase 3's client-side login exists**, `user_id` is instead a device-local placeholder UUID (`getOrCreateLocalUserId()`, `lib/progress/local_user_id.dart` - `SharedPreferences` key `local_user_id`, generated once via `Random.secure()`, not a backend-issued account id). This lets local progress tracking work standalone before accounts exist; migrating a device's accumulated local progress into a real account once login lands is not yet implemented (tracked in `../TODO.md`).

### 3.4 User Level Setting

The reader declares their current German level — one of `A1`, `A2`, `B1`, `B2` — via a UI control (Phase 2: a simple selector; not tied to any account system until Phase 3's backend exists). Stored as a single local preference (`SharedPreferences`, key `german_level`), not in the `word_progress` table above — it's a coarse, manually-set starting point, distinct from the per-word `status` progress `word_progress` tracks via Phase 4's adaptive engine. Defaults to `A1` for a new install. See section 4 for how it affects replacement.

### 3.5 User Accounts (email/password + social login) and Recent Documents (Phase 3.5 — spec'd, not yet built)

Extends the `users` table already built for Phase 3 (`backend/app/models.py`: `id`, `email`, `hashed_password`) rather than replacing it — email/password accounts keep working exactly as today.

```sql
-- New. One row per (provider, provider-side account) a user has linked.
-- A user can have a hashed_password, one or more oauth_accounts rows, or both.
CREATE TABLE oauth_accounts (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  provider TEXT NOT NULL,              -- 'google' | 'facebook' | 'twitter'
  provider_subject_id TEXT NOT NULL,   -- stable id the provider assigns that account
  provider_email TEXT,                 -- email as reported by the provider - may be absent/unverified, don't treat as equal to users.email
  UNIQUE (provider, provider_subject_id)
);
```

- `users.hashed_password` becomes nullable: an account created purely via social login has no password of its own.
- Sign-up via a provider that reports an email matching an *existing* `users.email` should link to that existing account (adding an `oauth_accounts` row) rather than erroring or silently creating a duplicate account - the reader almost certainly means "this is me." Exact matching rule (case-insensitive on `email`) is a reasonable default; flag for reconsideration if it causes surprises.
- Regardless of login method, the client ends up holding the same app-issued JWT `AuthService` already handles (`lib/auth/auth_service.dart`, built in Phase 3.5's `AuthService`/`ProgressSyncService` client work) - social login is a different way to *obtain* that JWT, not a different downstream flow. See section 7 for the OAuth mechanics.

```json
// New. SharedPreferences key 'recent_documents', JSON-encoded list, newest
// first, capped at ~8 entries (oldest dropped past the cap). Local-only,
// never synced to the backend - see section 7 for why.
{
  "document_id": "my_book",
  "title": "My Book",
  "file_path": "C:/Users/.../my_book.epub",
  "format": "epub",
  "last_opened_at": "2026-08-06T21:00:00Z"
}
```

```sql
-- New. Short-lived, single-use tokens for the forgot-password flow (7.4).
-- Only ever created for accounts that have a hashed_password - a purely
-- social-login account has nothing here to reset (see 7.4).
CREATE TABLE password_reset_tokens (
  token TEXT PRIMARY KEY,             -- random, high-entropy - this IS the emailed link's identifier, not a lookup key for one
  user_id TEXT NOT NULL REFERENCES users(id),
  expires_at TIMESTAMP NOT NULL,      -- short-lived, suggest 30-60 minutes
  used_at TIMESTAMP                   -- NULL until consumed; a used or expired token is rejected
);
```

- `document_id` here is the same value already used to key scroll position (`scroll_position_<document_id>` in `reader_view.dart`) and bookmarks - it's deterministically the file's basename without extension (see each parser's `document_id: ...basenameWithoutExtension(file.path)`), not a fresh UUID per open, so re-opening the same file already resumes at the right position today. This section formalizes surfacing that as a visible "recent documents" list rather than requiring the reader to know to reopen the same file.

---

## 4. Replacement Algorithm (Phase 2/4 logic — both built)

### 4.1 Level eligibility filter (Phase 2, built)

The reader's declared level (section 3.4) determines which vocabulary entries are even eligible for replacement, and the flat base rate applied to them:

- **Eligibility is cumulative**: a reader at level `N` sees replacements from every CEFR level at or below `N` — e.g. a `B1` reader gets `A1` + `A2` + `B1` words, never `B2`. This matches CEFR's own cumulative-curriculum design and keeps a beginner from being shown vocabulary far above them, while a `B2` reader still draws from the full dataset.
- **Base rate scales with level**: `A1: 10%`, `A2: 15%`, `B1: 20%`, `B2: 25%` (per-occurrence, independent rolls — same flat-rate mechanic as before, just level-parameterized instead of a single constant). Rationale: a more advanced reader is both drawing from a larger eligible pool and ready for denser replacement.
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
    html_parser.dart           // added post-Phase-1 (see acceptance criteria below) - not yet built
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
- [ ] **Added after Phase 1 originally shipped, not yet built:** Open a `.html`/`.htm` file — text extracted and reflowed the same as the other formats, tags/scripts/styles stripped, routed through the shared `DocumentParser.buildParagraphs()` 300-word cap like every other parser (see the Architecture section of `CLAUDE.md` for why that cap is load-bearing)

### Suggested libraries (verify current versions/maintenance status before committing)
- PDF text extraction: `syncfusion_flutter_pdf` or `pdf_text`
- DOCX parsing: `docx_to_text` or manual XML parsing (DOCX is a zip of XML — `archive` + `xml` packages can do it directly if no maintained package fits)
- EPUB parsing: `epubx` or manual zip/XHTML parsing (EPUB is also just zipped XHTML)
- HTML parsing: `package:html` (Dart's own html5 parser) is the obvious fit and, unlike `docx_to_text`/`epubx`, doesn't pin a conflicting `xml` version (see the DOCX/EPUB note in `CLAUDE.md`'s Architecture section) - verify that still holds before committing to it; manual regex/tag-stripping is the fallback if it doesn't

---

## 6. Later Phases (status noted per phase — Phase 5 is still the one genuinely not started)

- **Phase 2 (built):** Vocabulary dataset + tap-to-toggle UI + flat-rate random replacement, gated by a reader-declared CEFR level (section 4.1) — no depth/word-status adaptivity, that's Phase 4.
- **Phase 3 (backend-side built, client-side not started):** FastAPI backend — auth, vocabulary served from API, progress sync endpoint. Backend-side, all three exist (`backend/`) and are tested; client-side, only vocabulary-fetching is wired up (`VocabularyRepository`, with bundled-JSON fallback). The client still doesn't register, log in, or sync progress to the backend — Phase 4's progress tracking (below) is fully built and running, but purely local (see section 3.3's placeholder-`user_id` note); wiring it to the backend's `/auth` and `/progress` endpoints is separate, not-yet-started work, no longer blocked on Phase 4 since Phase 4 has shipped.
- **Phase 4 (built):** Depth/word-status replacement multipliers from section 4.2, and SM-2 progress tracking (`Sm2Scheduler`, `WordProgressRepository`, `LocalDb`) wired to real usage in `ReaderView`/`HomePage` — every replaced-word render and toggle updates real local progress, and that progress now actually drives replacement probability (see 4.2). Not yet synced to the backend (see Phase 3, above).
- **Phase 3.5 (client-side services built, UI not started):** Social login (Google/Facebook/Twitter, section 3.5/7), sign-out, forgot-password, and a "recent documents" resume screen (section 3.5/7). `AuthService` (register/login/logout against the existing email+password backend) and `ProgressSyncService` (push/pull `word_progress` to `/progress`) both exist and are tested (`lib/auth/`, `lib/progress/progress_sync_service.dart`) but nothing in the UI calls them yet — no login/register screen, no sign-out control, no recent-documents home screen. Social login, forgot-password, and the recent-documents screen (the `oauth_accounts`/`password_reset_tokens` tables, the new backend endpoints, the desktop OAuth system-browser flow) are all spec'd in section 7 but entirely unbuilt.
- **Phase 5 (not started):** Android/iOS builds, touch-target and mobile-layout polish.

---

## 7. Accounts, Social Login, Sign-Out, Forgot Password & Recent Documents (Phase 3.5 — spec'd, not yet built)

Data model for this section is in 3.5; this section is the actual flow/UX.

### 7.1 Registration and login

Two paths, both ending at the same place — the client holding an app-issued JWT via `AuthService` (`lib/auth/auth_service.dart`, already built):

1. **Email + password** (Phase 3 backend, already built and tested): `POST /auth/register` then `POST /auth/login`. Nothing changes here.
2. **Social login — Google, Facebook, Twitter/X** (not yet built): a desktop app can't safely embed any provider's OAuth client secret in a distributable binary, so the backend brokers the token exchange rather than the client talking to the provider directly:
   - Client opens the provider's OAuth consent page in the OS's default browser (`url_launcher` or equivalent) using the Authorization Code + PKCE flow (RFC 8252, the standard pattern for native/desktop apps), with the redirect URI pointing at a short-lived local HTTP listener the client spins up on an ephemeral loopback port (`http://127.0.0.1:<port>/callback`) just for this flow.
   - The provider redirects the browser back to that listener with an authorization code; the client grabs it and shuts the listener down.
   - Client sends that code to a new backend endpoint, `POST /auth/oauth/{provider}/callback` (mirrors the shape of the existing `/auth/login` — not yet built). The backend exchanges the code (with the provider's client secret, held server-side only, never shipped to the client) for the provider's identity info, upserts a `users`/`oauth_accounts` row per section 3.5's linking rule, and returns our own app JWT — same shape `/auth/login` already returns, so `AuthService`, `ProgressSyncService`, and everything downstream is identical regardless of which path got the reader there.
   - **Twitter/X caveat:** since the Twitter→X transition, X's OAuth 2.0 (needed for third-party sign-in) sits behind a paid developer API tier — free access doesn't reliably support this anymore. Confirm current X developer-platform pricing/terms before investing engineering time on it specifically; this constraint doesn't apply to Google, and Facebook's only extra step is a one-time app review before its login works for real (non-test) users in production.

### 7.2 Sign-out

`AuthService.logout()` (already built) clears the persisted JWT and email. Signing out must not block reading: it just reverts the app to the same local-only mode a fresh install starts in (the placeholder `user_id` from section 3.3), not a locked-out state. Needs a UI affordance — e.g. an account entry in the `AppBar` (currently has level selector / theme toggle / open-file, section on `HomePage` in `CLAUDE.md`) showing the signed-in email with a sign-out action, replaced by a sign-in prompt when logged out. Not yet built.

### 7.3 Recent documents / resume

On launch, instead of landing directly on "open a file" (today's behavior — see `HomePage`'s empty state), show up to ~8 most-recently-opened documents (title, last-opened time; reading-progress percentage is a nice-to-have derivable from `ReaderController`'s persisted scroll position but not required for v1), each tappable to reopen that exact file at its already-persisted scroll position — this reuses the existing `document_id`-keyed scroll-position/bookmark mechanism as-is (section 3.5 explains why no new plumbing is needed there). The existing "open another file" action (file-picker icon) stays available alongside the list, not replaced by it.

This list works **regardless of login state** — it's local-only (SharedPreferences, section 3.5) and never synced to the backend, since it stores local filesystem paths that are meaningless on another device. Logging in enables cross-device *progress* sync (Phase 3.5's `ProgressSyncService`, already built); it does not and should not make the recent-files list itself cross-device.

Must handle a listed file having since been moved/deleted without crashing — skip it or surface an inline "file not found" state on tap, don't let a stale path take down the home screen.

### 7.4 Forgot password

Only applies to accounts with a password at all — a purely social-login account has nothing to reset; its "forgot password" is just "sign in via the provider again" (no UI needed for that case beyond making sure the sign-in screen doesn't dead-end someone who never set a password).

- `POST /auth/forgot-password {email}` (not yet built) — generates a `password_reset_tokens` row (3.5) if that email has an account with a password, and emails a reset link containing the token. **Always returns 200 regardless of whether the email matches an account** — a differing response would let someone probe which emails are registered (user enumeration), so the "check your email" message is identical either way.
- `POST /auth/reset-password {token, new_password}` (not yet built) — rejects an unknown, expired, or already-used token; otherwise updates `users.hashed_password` and sets `used_at` so the token can't be replayed.
- **Open decision, not yet made:** sending the actual email needs a transactional email provider (e.g. SendGrid, Postmark, AWS SES) — nothing in this project sends email today. Recommend picking whichever has the most usable free tier for a pre-revenue POC (Postmark and SendGrid both have one); this is a genuine "propose changes here first" architecture decision per this doc's own intro, not something to silently pick mid-implementation.

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
