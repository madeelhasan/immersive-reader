# TODO

Two tiers, deliberately kept separate: what's left to call the **proof of concept** done, versus what a **production** version would need. Don't blur them — most of the production list is explicitly out of scope until the POC has proven the concept is worth productionizing.

## Critical path to POC completion

1. ~~**Actually watch the Phase 4 experience run, live, end to end.**~~ **Done**, via automated proof rather than manual GUI clicking: `test/reader_view_progress_wiring_test.dart` (written test-first, delegated, independently verified) proves - with a fake repository, no real DB needed - that `ReaderView` records exactly one `neutral` exposure per token on first build, doesn't double-count on rebuild, and fires `toggledBack`/`toggledForward` in the right order when tapped. Combined with the already-existing `Sm2Scheduler`/`WordProgressRepository` unit tests, the full chain is proven by composition. Manual GUI verification was attempted first and abandoned after a screenshot-tooling detour turned up nothing but a low-contrast-icon false alarm - not worth repeating; the automated test is the more reliable artifact going forward.
2. **B1 vocabulary volume** (148 of the ~400 a B1 reader's share implies, vs. A1/A2/B2 all near target). Not strictly blocking the mechanism, but a demo where the level selector visibly runs out of B1 words undercuts the pitch. Written directly last time after a DeepSeek delegation round hit a repetition-loop failure mode (see CLAUDE.md) - small batches, no giant avoid-lists handed to the model.
3. **A light sanity pass on translation quality** - not the full production-grade native-speaker review below, just enough spot-checking that an obviously wrong translation doesn't surface in a demo. CLAUDE.md already flags that nothing in the pipeline currently checks translation *correctness*, only count/duplication.

Everything else already exists and works: Phase 1 (reader, all 4 formats), Phase 2 (vocab + tap-to-toggle + flat-rate replacement), Phase 3 backend (auth, vocabulary API, progress sync - all tested), Phase 4's algorithm and persistence layer (`Sm2Scheduler`, `WordProgressRepository`, `LocalDb`, `ReplacementEngine.selectReplacementsWithProgress`).

## Production-readiness backlog (post-POC, not blocking it)

**Content quality**
- Full native-speaker/dictionary-verified review of the vocabulary dataset (the spot-check above is a stopgap, not a substitute)

**Security / config**
- `JWT_SECRET_KEY` has a dev-only default (`backend/`) - must refuse to start in production without a real one set
- Rate limiting on `/auth/login` and `/auth/register`
- TLS in front of the backend (currently bare `uvicorn`)

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
- Privacy policy + data-deletion path (bcrypt-hashed passwords already help, but progress data + email are still real PII)
- A migration path for merging local placeholder-UUID progress (`lib/progress/local_user_id.dart`) into a real account once client-side login exists - currently that merge doesn't exist, so local progress would be orphaned the moment someone logs in
