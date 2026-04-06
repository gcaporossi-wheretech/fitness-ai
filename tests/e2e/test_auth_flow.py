"""E2E test: complete authentication flow.

Tests: register -> login -> get profile -> update profile ->
       refresh tokens -> export data -> delete account.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Add auth service to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent / "services" / "auth"))

from tests.conftest import (  # noqa: E402
    TEST_DATABASE_URL,
    _make_sqlite_compatible,
)

from app.main import app  # noqa: E402
from app.models import Base  # noqa: E402
from app.database import get_db  # noqa: E402


@pytest.fixture
async def auth_client():
    """Create an E2E test client for auth service."""
    from httpx import ASGITransport, AsyncClient
    from sqlalchemy.ext.asyncio import (
        AsyncSession,
        async_sessionmaker,
        create_async_engine,
    )

    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    _make_sqlite_compatible(Base)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async def override_get_db():
        async with session_factory() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)

    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client

    app.dependency_overrides.clear()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.mark.asyncio
async def test_full_auth_lifecycle(auth_client):
    """E2E: register -> login -> profile -> update -> refresh -> export -> delete."""
    client = auth_client

    # 1. Register
    reg_resp = await client.post(
        "/auth/register",
        json={
            "email": "e2e@example.com",
            "password": "E2eTest123",
            "name": "E2E User",
            "language": "en",
        },
    )
    assert reg_resp.status_code == 201
    tokens = reg_resp.json()["tokens"]
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}
    refresh_token = tokens["refresh_token"]

    # 2. Login with same credentials
    login_resp = await client.post(
        "/auth/login",
        json={"email": "e2e@example.com", "password": "E2eTest123"},
    )
    assert login_resp.status_code == 200
    assert login_resp.json()["user"]["email"] == "e2e@example.com"

    # 3. Get profile
    profile_resp = await client.get("/auth/me", headers=headers)
    assert profile_resp.status_code == 200
    assert profile_resp.json()["name"] == "E2E User"
    assert profile_resp.json()["language"] == "en"

    # 4. Update profile
    update_resp = await client.patch(
        "/auth/me",
        headers=headers,
        json={"name": "Updated E2E", "age": 30},
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "Updated E2E"
    assert update_resp.json()["age"] == 30

    # 5. Refresh tokens
    refresh_resp = await client.post(
        "/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_resp.status_code == 200
    new_tokens = refresh_resp.json()
    assert new_tokens["access_token"] != tokens["access_token"]
    headers = {"Authorization": f"Bearer {new_tokens['access_token']}"}

    # 6. Check credits
    credits_resp = await client.get("/auth/credits", headers=headers)
    assert credits_resp.status_code == 200
    assert credits_resp.json()["credits"] == 10  # Default credits

    # 7. Export data (GDPR)
    export_resp = await client.get("/auth/me/export", headers=headers)
    assert export_resp.status_code == 200
    export = export_resp.json()
    assert export["profile"]["name"] == "Updated E2E"
    assert export["export_version"] == "1.0"

    # 8. Delete account (GDPR)
    delete_resp = await client.request(
        "DELETE",
        "/auth/me",
        headers=headers,
        json={"password": "E2eTest123"},
    )
    assert delete_resp.status_code == 204

    # 9. Verify account is gone
    check_resp = await client.get("/auth/me", headers=headers)
    assert check_resp.status_code == 401


@pytest.mark.asyncio
async def test_webauthn_registration_and_login(auth_client):
    """E2E: register -> WebAuthn register -> WebAuthn login."""
    client = auth_client

    # Register user
    reg_resp = await client.post(
        "/auth/register",
        json={
            "email": "webauthn-e2e@example.com",
            "password": "WebAuth123",
            "name": "WebAuthn User",
        },
    )
    assert reg_resp.status_code == 201
    headers = {
        "Authorization": f"Bearer {reg_resp.json()['tokens']['access_token']}"
    }

    # Begin WebAuthn registration
    begin_resp = await client.post(
        "/auth/webauthn/register/begin", headers=headers
    )
    assert begin_resp.status_code == 200
    assert "challenge" in begin_resp.json()

    # Complete WebAuthn registration
    complete_resp = await client.post(
        "/auth/webauthn/register/complete",
        headers=headers,
        json={
            "credential_id": "e2e-passkey-001",
            "public_key": "e2e-public-key-base64",
            "device_name": "E2E Test Device",
        },
    )
    assert complete_resp.status_code == 200

    # List credentials
    list_resp = await client.get(
        "/auth/webauthn/credentials", headers=headers
    )
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1
    assert list_resp.json()[0]["device_name"] == "E2E Test Device"

    # Login via WebAuthn
    login_resp = await client.post(
        "/auth/webauthn/login",
        json={
            "credential_id": "e2e-passkey-001",
            "authenticator_data": "e2e-auth-data",
            "client_data_json": "e2e-client-data",
            "signature": "e2e-signature",
        },
    )
    assert login_resp.status_code == 200
    assert login_resp.json()["user"]["email"] == "webauthn-e2e@example.com"
    assert login_resp.json()["tokens"]["access_token"]
