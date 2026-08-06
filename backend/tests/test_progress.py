def test_progress_requires_auth(client):
    assert client.post("/progress", json={"entries": []}).status_code == 401
    assert client.get("/progress").status_code == 401


def test_sync_progress_creates_new_rows(client, auth_headers):
    headers = auth_headers("user1@example.com")
    payload = {
        "entries": [
            {"en_word": "house", "exposures": 3, "status": "introduced"},
            {"en_word": "journey", "exposures": 1},
        ],
    }
    response = client.post("/progress", json=payload, headers=headers)
    assert response.status_code == 200
    assert response.json()["synced"] == 2

    get_response = client.get("/progress", headers=headers)
    assert get_response.status_code == 200
    body = {row["en_word"]: row for row in get_response.json()}
    assert body["house"]["exposures"] == 3
    assert body["house"]["status"] == "introduced"
    assert body["journey"]["exposures"] == 1
    assert body["journey"]["status"] == "new"  # default


def test_sync_progress_upserts_existing_rows(client, auth_headers):
    headers = auth_headers("user2@example.com")
    client.post("/progress", json={"entries": [{"en_word": "house", "exposures": 1}]}, headers=headers)
    response = client.post(
        "/progress",
        json={"entries": [{"en_word": "house", "exposures": 5, "status": "learned"}]},
        headers=headers,
    )
    assert response.status_code == 200

    rows = client.get("/progress", headers=headers).json()
    assert len(rows) == 1
    assert rows[0]["exposures"] == 5
    assert rows[0]["status"] == "learned"


def test_progress_is_isolated_per_user(client, auth_headers):
    headers_a = auth_headers("user-a@example.com")
    headers_b = auth_headers("user-b@example.com")
    client.post("/progress", json={"entries": [{"en_word": "house"}]}, headers=headers_a)
    client.post("/progress", json={"entries": [{"en_word": "journey"}]}, headers=headers_b)

    assert len(client.get("/progress", headers=headers_a).json()) == 1
    assert len(client.get("/progress", headers=headers_b).json()) == 1


def test_get_progress_for_new_user_returns_empty(client, auth_headers):
    headers = auth_headers("brand-new@example.com")
    response = client.get("/progress", headers=headers)
    assert response.status_code == 200
    assert response.json() == []
