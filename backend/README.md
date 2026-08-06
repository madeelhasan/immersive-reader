# Immersive Reader API (Phase 3)

FastAPI backend per `../spec/SPEC.md` sections 2/3.2/3.3/6. Serves the vocabulary dataset and syncs per-user word progress. Not yet consumed by the Flutter app (`../app/immersive_reader/`) — that's a deliberately separate follow-up; the client still uses its bundled `assets/vocab/en_de_starter.json` copy for now.

## Status

- `GET /vocabulary` (optional `?cefr_level=A1` filter) — done.
- `POST /progress`, `GET /progress/{user_id}` — done.
- Auth — deferred. `user_id` is currently just a client-supplied opaque string (e.g. a UUID the app would generate and persist locally), not derived from a login. See `app/schemas.py`'s `ProgressSyncRequest` for the seam where real auth will slot in later without changing the request shape.
- Hosting (Render/Fly.io/Railway free tier) — not deployed yet, local-only so far.

## Setup

Uses a dedicated Python 3.11 venv (`C:\Users\adeel\backend-venv`) for the same reason `aider-venv` does — this machine's system Python (3.14) has a pip dependency-resolver bug that silently falls back to ancient package releases.

```
C:\Users\adeel\backend-venv\Scripts\pip.exe install -r requirements.txt
C:\Users\adeel\backend-venv\Scripts\python.exe -m pytest
C:\Users\adeel\backend-venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

The vocabulary table seeds itself once, on first startup, from `../app/immersive_reader/assets/vocab/en_de_starter.json` — that file is the single source of truth for vocabulary data; the backend doesn't maintain a separate copy. Delete the local `immersive_reader.db` file to force a re-seed (e.g. after the dataset grows).

Default DB is `sqlite:///./immersive_reader.db` (gitignored); override with the `DATABASE_URL` env var (e.g. for Postgres later, per SPEC.md section 2's SQLite→Postgres migration path).
