"""Unit tests for JWT dependencies: decode_access_token and get_current_user_id."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from jose import jwt

from app.config import settings
from app.dependencies import decode_access_token, get_current_user_id


def _make_token(payload: dict) -> str:
    """Encode a JWT token with the test secret."""
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def test_decode_valid_access_token():
    """decode_access_token should return payload for a valid access token."""
    payload = {
        "sub": str(uuid.uuid4()),
        "type": "access",
        "exp": datetime.now(UTC) + timedelta(minutes=15),
    }
    token = _make_token(payload)
    result = decode_access_token(token)

    assert result is not None
    assert result["sub"] == payload["sub"]
    assert result["type"] == "access"


def test_decode_token_wrong_type():
    """decode_access_token should return None for non-access token type."""
    payload = {
        "sub": str(uuid.uuid4()),
        "type": "refresh",
        "exp": datetime.now(UTC) + timedelta(minutes=15),
    }
    token = _make_token(payload)
    result = decode_access_token(token)

    assert result is None


def test_decode_token_expired():
    """decode_access_token should return None for an expired token."""
    payload = {
        "sub": str(uuid.uuid4()),
        "type": "access",
        "exp": datetime.now(UTC) - timedelta(minutes=1),
    }
    token = _make_token(payload)
    result = decode_access_token(token)

    assert result is None


def test_decode_token_invalid():
    """decode_access_token should return None for a garbage token."""
    result = decode_access_token("not.a.valid.jwt.token")
    assert result is None


@pytest.mark.asyncio
async def test_get_current_user_id_valid():
    """get_current_user_id should return UUID for a valid token."""
    user_id = str(uuid.uuid4())
    payload = {
        "sub": user_id,
        "type": "access",
        "exp": datetime.now(UTC) + timedelta(minutes=15),
    }
    token = _make_token(payload)
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)

    result = await get_current_user_id(credentials)
    assert result == uuid.UUID(user_id)


@pytest.mark.asyncio
async def test_get_current_user_id_invalid_token():
    """get_current_user_id should raise 401 for an invalid token."""
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials="bad-token")

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_id(credentials)
    assert exc_info.value.status_code == 401
    assert "Invalid or expired" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_user_id_missing_sub():
    """get_current_user_id should raise 401 when sub is missing from payload."""
    payload = {
        "type": "access",
        "exp": datetime.now(UTC) + timedelta(minutes=15),
    }
    token = _make_token(payload)
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_id(credentials)
    assert exc_info.value.status_code == 401
    assert "Invalid token payload" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_user_id_invalid_uuid():
    """get_current_user_id should raise 401 when sub is not a valid UUID."""
    payload = {
        "sub": "not-a-uuid",
        "type": "access",
        "exp": datetime.now(UTC) + timedelta(minutes=15),
    }
    token = _make_token(payload)
    credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_id(credentials)
    assert exc_info.value.status_code == 401
    assert "Invalid token payload" in exc_info.value.detail
