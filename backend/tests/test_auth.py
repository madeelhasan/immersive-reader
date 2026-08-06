def test_register_creates_user(client):
    response = client.post("/auth/register", json={"email": "a@example.com", "password": "password123"})
    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "a@example.com"
    assert "id" in body
    assert "password" not in body and "hashed_password" not in body


def test_register_rejects_duplicate_email(client):
    client.post("/auth/register", json={"email": "dupe@example.com", "password": "password123"})
    response = client.post("/auth/register", json={"email": "dupe@example.com", "password": "password456"})
    assert response.status_code == 400


def test_register_rejects_short_password(client):
    response = client.post("/auth/register", json={"email": "short@example.com", "password": "abc"})
    assert response.status_code == 422


def test_login_returns_token(client):
    client.post("/auth/register", json={"email": "b@example.com", "password": "password123"})
    response = client.post("/auth/login", json={"email": "b@example.com", "password": "password123"})
    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert len(body["access_token"]) > 0


def test_login_rejects_wrong_password(client):
    client.post("/auth/register", json={"email": "c@example.com", "password": "password123"})
    response = client.post("/auth/login", json={"email": "c@example.com", "password": "wrongpassword"})
    assert response.status_code == 401


def test_login_rejects_unknown_email(client):
    response = client.post("/auth/login", json={"email": "nobody@example.com", "password": "password123"})
    assert response.status_code == 401
