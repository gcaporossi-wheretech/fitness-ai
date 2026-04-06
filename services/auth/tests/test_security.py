"""Security hardening tests for auth service.

Tests for auth bypass, injection, malformed tokens, and edge cases.
"""

from __future__ import annotations

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_expired_token_rejected(client: AsyncClient):
    """Expired JWT should be rejected with 401."""
    from datetime import UTC, datetime, timedelta

    from jose import jwt

    from app.config import settings

    payload = {
        "sub": "550e8400-e29b-41d4-a716-446655440000",
        "exp": datetime.now(UTC) - timedelta(minutes=1),  # expired
        "iat": datetime.now(UTC) - timedelta(minutes=16),
        "type": "access",
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
    headers = {"Authorization": f"Bearer {token}"}

    resp = await client.get("/auth/me", headers=headers)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_wrong_secret_token_rejected(client: AsyncClient):
    """JWT signed with wrong secret should be rejected."""
    from datetime import UTC, datetime, timedelta

    from jose import jwt

    payload = {
        "sub": "550e8400-e29b-41d4-a716-446655440000",
        "exp": datetime.now(UTC) + timedelta(minutes=15),
        "iat": datetime.now(UTC),
        "type": "access",
    }
    token = jwt.encode(payload, "wrong-secret-key-12345678901234", algorithm="HS256")
    headers = {"Authorization": f"Bearer {token}"}

    resp = await client.get("/auth/me", headers=headers)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_malformed_token_rejected(client: AsyncClient):
    """Malformed token should be rejected."""
    headers = {"Authorization": "Bearer not.a.valid.jwt.token"}
    resp = await client.get("/auth/me", headers=headers)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_missing_bearer_prefix_rejected(client: AsyncClient):
    """Authorization without Bearer prefix should fail."""
    headers = {"Authorization": "just-a-token-string"}
    resp = await client.get("/auth/me", headers=headers)
    assert resp.status_code in (401, 403)


@pytest.mark.asyncio
async def test_sql_injection_email(client: AsyncClient):
    """SQL injection in email field should be rejected by validation."""
    resp = await client.post(
        "/auth/login",
        json={
            "email": "admin@example.com' OR '1'='1",
            "password": "anything",
        },
    )
    # Should be rejected by Pydantic email validation (422) or login failure (401)
    assert resp.status_code in (401, 422)


@pytest.mark.asyncio
async def test_sql_injection_password(client: AsyncClient):
    """SQL injection in password should not bypass auth."""
    # First register a user
    await client.post(
        "/auth/register",
        json={
            "email": "sqli-test@example.com",
            "password": "ValidPass123",
        },
    )

    resp = await client.post(
        "/auth/login",
        json={
            "email": "sqli-test@example.com",
            "password": "' OR '1'='1",
        },
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_oversized_payload_rejected(client: AsyncClient):
    """Extremely large payload should be handled gracefully."""
    resp = await client.post(
        "/auth/register",
        json={
            "email": "big@example.com",
            "password": "A" * 200,  # Over max_length=128
            "name": "Test",
        },
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_empty_body_rejected(client: AsyncClient):
    """Empty request body should return 422."""
    resp = await client.post("/auth/register", content=b"")
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_wrong_content_type_rejected(client: AsyncClient):
    """Non-JSON content type should be handled."""
    resp = await client.post(
        "/auth/register",
        content=b"email=test@test.com&password=test",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_token_type_refresh_not_accepted_as_access(client: AsyncClient):
    """Refresh token type should not be accepted as access token."""
    from datetime import UTC, datetime, timedelta

    from jose import jwt

    from app.config import settings

    payload = {
        "sub": "550e8400-e29b-41d4-a716-446655440000",
        "exp": datetime.now(UTC) + timedelta(days=7),
        "iat": datetime.now(UTC),
        "type": "refresh",  # wrong type
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm="HS256")
    headers = {"Authorization": f"Bearer {token}"}

    resp = await client.get("/auth/me", headers=headers)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_unicode_injection_name(client: AsyncClient):
    """Unicode characters in name should be handled safely."""
    resp = await client.post(
        "/auth/register",
        json={
            "email": "unicode@example.com",
            "password": "TestPass123",
            "name": "<script>alert('xss')</script>",
        },
    )
    # Should succeed (stored as-is, XSS is output-side concern)
    # OR be rejected by validation — either is acceptable
    assert resp.status_code in (201, 422)
    if resp.status_code == 201:
        # If stored, verify it's returned as-is (not executed)
        token = resp.json()["tokens"]["access_token"]
        profile = await client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert "<script>" in profile.json()["name"]
