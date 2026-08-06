"""In-memory fixed-window rate limiting for auth endpoints.

Single-process only - a real multi-worker/multi-instance production
deployment would need a shared store (Redis or similar) instead. This is
deliberately dependency-free and enough for basic brute-force protection
at this project's current scale.
"""

import time
from collections import defaultdict, deque
from typing import Callable, Deque, Dict

from fastapi import HTTPException, Request, status


class RateLimiter:
    def __init__(
        self,
        max_requests: int,
        window_seconds: float,
        time_fn: Callable[[], float] = time.monotonic,
    ):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._time_fn = time_fn
        self._requests: Dict[str, Deque[float]] = defaultdict(deque)

    def allow(self, key: str) -> bool:
        now = self._time_fn()
        window_start = now - self.window_seconds
        timestamps = self._requests[key]
        while timestamps and timestamps[0] < window_start:
            timestamps.popleft()
        if len(timestamps) >= self.max_requests:
            return False
        timestamps.append(now)
        return True

    def reset(self) -> None:
        self._requests.clear()


login_limiter = RateLimiter(max_requests=5, window_seconds=60.0)
register_limiter = RateLimiter(max_requests=5, window_seconds=60.0)


def _client_key(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def rate_limit_login(request: Request) -> None:
    if not login_limiter.allow(_client_key(request)):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts, please try again later",
        )


def rate_limit_register(request: Request) -> None:
    if not register_limiter.allow(_client_key(request)):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many registration attempts, please try again later",
        )


def reset_all_rate_limiters() -> None:
    login_limiter.reset()
    register_limiter.reset()
