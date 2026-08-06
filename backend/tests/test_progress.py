def test_sync_progress_creates_new_rows(client):
    payload = {
        "user_id": "user-1",
        "entries": [
            {"en_word": "house", "exposures": 3, "status": "introduced"},
            {"en_word": "journey", "exposures": 1},
        ],
    }
    response = client.post("/progress", json=payload)
    assert response.status_code == 200
    assert response.json() == {"user_id": "user-1", "synced": 2}

    get_response = client.get("/progress/user-1")
    assert get_response.status_code == 200
    body = {row["en_word"]: row for row in get_response.json()}
    assert body["house"]["exposures"] == 3
    assert body["house"]["status"] == "introduced"
    assert body["journey"]["exposures"] == 1
    assert body["journey"]["status"] == "new"  # default


def test_sync_progress_upserts_existing_rows(client):
    client.post(
        "/progress",
        json={"user_id": "user-2", "entries": [{"en_word": "house", "exposures": 1}]},
    )
    response = client.post(
        "/progress",
        json={"user_id": "user-2", "entries": [{"en_word": "house", "exposures": 5, "status": "learned"}]},
    )
    assert response.status_code == 200

    rows = client.get("/progress/user-2").json()
    assert len(rows) == 1
    assert rows[0]["exposures"] == 5
    assert rows[0]["status"] == "learned"


def test_progress_is_isolated_per_user(client):
    client.post("/progress", json={"user_id": "user-a", "entries": [{"en_word": "house"}]})
    client.post("/progress", json={"user_id": "user-b", "entries": [{"en_word": "journey"}]})

    assert len(client.get("/progress/user-a").json()) == 1
    assert len(client.get("/progress/user-b").json()) == 1


def test_get_progress_for_unknown_user_returns_empty(client):
    response = client.get("/progress/nobody")
    assert response.status_code == 200
    assert response.json() == []
