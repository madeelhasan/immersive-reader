# Immersive Reader API (Phase 3)

FastAPI backend per `../spec/SPEC.md` sections 2/3.2/3.3/6. Serves the vocabulary dataset, authenticates users, and syncs per-user word progress. The Flutter app (`../app/immersive_reader/`) fetches vocabulary from this API when it's reachable, falling back to its bundled `assets/vocab/en_de_starter.json` copy otherwise (see `lib/vocabulary/vocabulary_repository.dart`) - it doesn't yet call `/auth` or `/progress`, since those tie into Phase 4's client-side progress tracking, a separate piece of work.

## Status

- `GET /vocabulary` (optional `?cefr_level=A1` filter) — done, and consumed by the Flutter client.
- `POST /auth/register`, `POST /auth/login` — done. Bcrypt-hashed passwords, JWT bearer tokens (one-week expiry).
- `POST /progress`, `GET /progress` — done, both require a valid bearer token; `user_id` is derived from it server-side, not client-supplied.
- Hosting (Render/Fly.io/Railway free tier) — not deployed yet, local-only so far. `JWT_SECRET_KEY` has a dev-only default in `app/security.py` that MUST be overridden via env var before any real deployment.

## Setup

Uses a dedicated Python 3.11 venv (`C:\Users\adeel\backend-venv`) for the same reason `aider-venv` does — this machine's system Python (3.14) has a pip dependency-resolver bug that silently falls back to ancient package releases.

```
C:\Users\adeel\backend-venv\Scripts\pip.exe install -r requirements.txt
C:\Users\adeel\backend-venv\Scripts\python.exe -m pytest
C:\Users\adeel\backend-venv\Scripts\python.exe -m uvicorn app.main:app --reload
```

The vocabulary table seeds itself once, on first startup, from `../app/immersive_reader/assets/vocab/en_de_starter.json` — that file is the single source of truth for vocabulary data; the backend doesn't maintain a separate copy. Delete the local `immersive_reader.db` file to force a re-seed (e.g. after the dataset grows).

Default DB is `sqlite:///./immersive_reader.db` (gitignored); override with the `DATABASE_URL` env var (e.g. for Postgres later, per SPEC.md section 2's SQLite→Postgres migration path).

## Auth flow

```
curl -X POST localhost:8000/auth/register -d '{"email":"you@example.com","password":"..."}'
curl -X POST localhost:8000/auth/login -d '{"email":"you@example.com","password":"..."}'
# -> {"access_token": "...", "token_type": "bearer"}
curl localhost:8000/progress -H "Authorization: Bearer <access_token>"
```

`GET /vocabulary` stays unauthenticated - it's public, read-only static content with no per-user data.
