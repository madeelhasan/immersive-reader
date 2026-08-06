import os
import tempfile
from pathlib import Path

# Must happen before `app.database` (and anything importing it) is loaded,
# since DATABASE_URL is read once at module import time. Using one shared
# file-backed DB for the whole test session rather than per-test isolation
# keeps this simple: the vocabulary table is seed-once/read-only in tests,
# and every progress test uses a distinct user_id, so cross-test state
# doesn't collide.
_TEST_DB_PATH = Path(tempfile.gettempdir()) / "immersive_reader_test.db"
if _TEST_DB_PATH.exists():
    _TEST_DB_PATH.unlink()
os.environ["DATABASE_URL"] = f"sqlite:///{_TEST_DB_PATH}"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


@pytest.fixture()
def client():
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture()
def auth_headers(client):
    """Returns a factory: auth_headers(email) -> registers + logs in that
    email and returns an Authorization header dict ready to pass to
    client.get/post. Each call uses a fresh email to get an isolated user."""

    def _make(email: str, password: str = "password123") -> dict:
        client.post("/auth/register", json={"email": email, "password": password})
        response = client.post("/auth/login", json={"email": email, "password": password})
        token = response.json()["access_token"]
        return {"Authorization": f"Bearer {token}"}

    return _make
