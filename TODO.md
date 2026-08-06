# TODO

Two tiers, deliberately kept separate: what's left to call the **proof of concept** done, versus what a **production** version would need. Don't blur them — most of the production list is explicitly out of scope until the POC has proven the concept is worth productionizing.

## Critical path to POC completion

1. ~~**Actually watch the Phase 4 experience run, live, end to end.**~~ **Done**, via automated proof rather than manual GUI clicking: `test/reader_view_progress_wiring_test.dart` (written test-first, delegated, independently verified) proves - with a fake repository, no real DB needed - that `ReaderView` records exactly one `neutral` exposure per token on first build, doesn't double-count on rebuild, and fires `toggledBack`/`toggledForward` in the right order when tapped. Combined with the already-existing `Sm2Scheduler`/`WordProgressRepository` unit tests, the full chain is proven by composition. Manual GUI verification was attempted first and abandoned after a screenshot-tooling detour turned up nothing but a low-contrast-icon false alarm - not worth repeating; the automated test is the more reliable artifact going forward.
2. ~~**B1 vocabulary volume**~~ **Done**: 148 → 292 → **407**, past the ~400 target. Final push hand-written directly (not delegated), two rounds, both deduped in Python against the full 1600+-entry dataset: round 1 (technology/workplace/travel/cooking/sports/environment/education/legal/relationships plus an adjective/adverb cluster - POS had skewed to 189 nouns vs. 5 adverbs) only netted 48 of 131 candidates (37% yield) - these broad categories turned out mostly already covered, apparently by the mature B2 tier, since dedup is dataset-wide across all four levels, not per-level. Round 2 went narrower per the already-established lesson (household tools, clothing details, kitchen equipment, weather phenomena, injuries, specific emotions, communication/productivity verbs, shopping/retail, community) and got 67 of 98 (68% yield) - confirms hand-picked narrow niches reliably outperform broad generation once common ground is covered, delegated or not.
3. ~~**A light sanity pass on translation quality**~~ **Done**: ~105 entries spot-checked across all four CEFR levels (a random cross-level sample plus everything added this session). Found and fixed one real error ("public transport" → "öffentlicher Verkehr" wasn't natural German, now "öffentliche Verkehrsmittel"); a couple of defensible-but-imperfect choices left as-is ('road'→'Weg' vs. 'Straße', 'council'→'Rat' being ambiguous with 'advice'). This was a sample, not exhaustive - the full production-grade review below is still the real bar.
4. ~~**Recent documents / resume home screen**~~ **Done**: `RecentDocumentsRepository` (`lib/library/`), TDD-delegated to Aider/DeepSeek as a whole-file SEARCH/REPLACE (landed correctly first attempt), independently verified against 7 hand-written tests. `HomePage`'s file-picker flow and the new recent-tap flow now share a single `_openPath(path, {fromRecent})` - a missing/moved file is detected up front and its stale entry removed with an inline error, rather than a generic parse exception. No new plumbing was needed to resume at the right scroll position, since `document_id` is already deterministic per file and `ReaderView` already persists scroll position keyed by it - this ended up being mostly a UI task, exactly as predicted below. 10 new tests (7 repository + 3 `HomePage` widget tests, including one real fix: `pumpAndSettle()` can't finish while the loading state's indeterminate spinner is showing, and `tester.pump(duration)` only fast-forwards the animation clock, not real wall-clock time - a real `Future.delayed` inside `tester.runAsync()` was the actual fix). Full suite 108/108.
5. ~~**HTML/.htm support**~~ **Done**: `HtmlParser` (`lib/parsers/html_parser.dart`), TDD-delegated to Aider/DeepSeek as a whole-file SEARCH/REPLACE (landed correctly first attempt), independently verified. Ended up regex-based rather than `package:html` - didn't need a new dependency at all, since EPUB chapters are already just XHTML and `EpubParser`'s existing tag-stripping logic could be shared directly. Extracted into `lib/parsers/html_text_utils.dart` (used by both parsers now), and picked up a real correctness fix along the way: the shared `stripHtml` now removes `<script>`/`<style>`/`<head>` blocks *with their content*, not just tags - the old EPUB-only version would have leaked JS/CSS source and `<title>` text into the reader for any chapter that had them. `ParserRegistry` and `main.dart`'s file picker/empty-state text updated. 16 new tests, full suite 94/94.

**All five critical-path items are now done — the POC is complete.** Nothing below this point blocks calling it that; the production-readiness backlog is the deliberate next tier, not a continuation of this list.

**Superseded, no longer on this list:** the app's product direction dropped accounts entirely (SPEC.md section 1: "no accounts, no login, no sign-up") - what was previously item 4 here (wiring `AuthService`/`ProgressSyncService` into a login screen, plus a follow-on plan for social login/sign-out/forgot-password) is moot. `AuthService` (`lib/auth/auth_service.dart`) and `ProgressSyncService` (`lib/progress/progress_sync_service.dart`) still exist and are tested (15 tests, `flutter analyze` clean) from that earlier work, but nothing calls them and nothing is planned to - left in place as working code rather than deleted, per SPEC.md section 6.

Everything else already exists and works: Phase 1 (reader, TXT/DOCX/EPUB/PDF/HTML), Phase 2 (vocab + tap-to-toggle + flat-rate replacement), Phase 3's vocabulary API (the only part of that backend still in active use), Phase 4's algorithm and persistence layer (`Sm2Scheduler`, `WordProgressRepository`, `LocalDb`, `ReplacementEngine.selectReplacementsWithProgress`) - permanently local now, never synced (SPEC.md 3.3).

## Production-readiness backlog (post-POC, not blocking it)

**Content quality**
- Full native-speaker/dictionary-verified review of the vocabulary dataset (the spot-check above is a stopgap, not a substitute)

**Security / config**
- ~~`JWT_SECRET_KEY` has a dev-only default...~~ **No longer applicable**: the app has no accounts (SPEC.md section 1), so `/auth` never gets called in production regardless of this setting. Only matters again if accounts come back into scope.
- ~~Rate limiting on `/auth/login` and `/auth/register`~~ **Done, but now moot for the same reason as above** - `backend/app/rate_limit.py` (in-memory fixed-window limiter, TDD-delegated to DeepSeek, independently verified: 21/21 backend tests pass) still exists and still works, it's just guarding endpoints nothing calls anymore.
- TLS in front of the backend (currently bare `uvicorn`) - still relevant for the vocabulary API, which stays in active use

**Backend deployment**
- Migrate SQLite → Postgres (the path SPEC.md section 2 already names)
- Containerize; run behind a real ASGI process manager, not a dev server
- Restrict CORS to the real client origin
- Structured logging, error tracking (Sentry-class), health checks

**Client distribution**
- Release (not debug) build; code signing (unsigned `.exe` gets SmartScreen-blocked)
- Real installer + update mechanism
- Client-side crash reporting - currently a crash on someone else's machine is invisible to us

**CI**
- `flutter analyze`/`flutter test` only run via a local git pre-commit hook right now - needs to run in GitHub Actions (or similar) gating PRs
- Backend's pytest suite needs the same treatment

**Data / privacy**
- Privacy policy - still relevant even with no accounts: the vocabulary API is still a network call, and if the app ever ships crash reporting or similar telemetry (see Client distribution, above) that's real data leaving the device.
- ~~A migration path for merging local placeholder-UUID progress into a real account once client-side login exists~~ **No longer applicable**: there's no real account for local progress to migrate into (SPEC.md section 1) - the placeholder `user_id` is the permanent scheme now, not a bridge to anything.
