from app.rate_limit import RateLimiter


def test_allows_requests_up_to_the_limit():
    clock = [0.0]
    limiter = RateLimiter(max_requests=3, window_seconds=60.0, time_fn=lambda: clock[0])
    assert limiter.allow("a") is True
    assert limiter.allow("a") is True
    assert limiter.allow("a") is True
    assert limiter.allow("a") is False


def test_different_keys_are_tracked_independently():
    clock = [0.0]
    limiter = RateLimiter(max_requests=1, window_seconds=60.0, time_fn=lambda: clock[0])
    assert limiter.allow("a") is True
    assert limiter.allow("b") is True
    assert limiter.allow("a") is False


def test_requests_are_allowed_again_after_the_window_expires():
    clock = [0.0]
    limiter = RateLimiter(max_requests=1, window_seconds=60.0, time_fn=lambda: clock[0])
    assert limiter.allow("a") is True
    assert limiter.allow("a") is False
    clock[0] = 61.0
    assert limiter.allow("a") is True


def test_reset_clears_all_tracked_requests():
    clock = [0.0]
    limiter = RateLimiter(max_requests=1, window_seconds=60.0, time_fn=lambda: clock[0])
    assert limiter.allow("a") is True
    limiter.reset()
    assert limiter.allow("a") is True


def test_login_endpoint_returns_429_after_too_many_attempts(client):
    client.post("/auth/register", json={"email": "ratelimit1@example.com", "password": "password123"})
    for _ in range(5):
        response = client.post(
            "/auth/login",
            json={"email": "ratelimit1@example.com", "password": "wrongpassword"},
        )
        assert response.status_code == 401
    response = client.post(
        "/auth/login",
        json={"email": "ratelimit1@example.com", "password": "wrongpassword"},
    )
    assert response.status_code == 429


def test_register_endpoint_returns_429_after_too_many_attempts(client):
    for i in range(5):
        client.post(
            "/auth/register",
            json={"email": f"ratelimit_reg_{i}@example.com", "password": "password123"},
        )
    response = client.post(
        "/auth/register",
        json={"email": "ratelimit_reg_overflow@example.com", "password": "password123"},
    )
    assert response.status_code == 429
