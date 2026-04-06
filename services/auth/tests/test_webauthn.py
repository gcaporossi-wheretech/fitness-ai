"""Tests for WebAuthn registration and login endpoints."""

from __future__ import annotations

import pytest
from httpx import AsyncClient

from tests.conftest import register_and_get_token


@pytest.mark.asyncio
async def test_webauthn_register_begin(client: AsyncClient):
    """Begin registration should return challenge and RP info."""
    headers = await register_and_get_token(client)

    response = await client.post(
        "/auth/webauthn/register/begin",
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert "challenge" in data
    assert data["rp_id"] == "fitnessai.app"
    assert data["rp_name"] == "FitnessAI"
    assert data["timeout"] == 60000
    assert "user_id" in data
    assert "user_name" in data


@pytest.mark.asyncio
async def test_webauthn_register_complete(client: AsyncClient):
    """Complete registration should store the credential."""
    headers = await register_and_get_token(client)

    # Begin registration
    begin_resp = await client.post(
        "/auth/webauthn/register/begin",
        headers=headers,
    )
    assert begin_resp.status_code == 200

    # Complete registration
    response = await client.post(
        "/auth/webauthn/register/complete",
        headers=headers,
        json={
            "credential_id": "test-credential-id-abc123",
            "public_key": "test-public-key-xyz789",
            "device_name": "iPhone 15 Pro",
        },
    )
    assert response.status_code == 200
    data = response.json()
    assert data["credential_id"] == "test-credential-id-abc123"
    assert data["device_name"] == "iPhone 15 Pro"
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_webauthn_register_no_auth(client: AsyncClient):
    """Register without auth should fail."""
    response = await client.post("/auth/webauthn/register/begin")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_webauthn_register_duplicate_credential(client: AsyncClient):
    """Registering duplicate credential should fail."""
    headers = await register_and_get_token(client)

    # Register first credential
    await client.post("/auth/webauthn/register/begin", headers=headers)
    await client.post(
        "/auth/webauthn/register/complete",
        headers=headers,
        json={
            "credential_id": "duplicate-cred-id",
            "public_key": "pub-key-1",
        },
    )

    # Try to register same credential again
    await client.post("/auth/webauthn/register/begin", headers=headers)
    response = await client.post(
        "/auth/webauthn/register/complete",
        headers=headers,
        json={
            "credential_id": "duplicate-cred-id",
            "public_key": "pub-key-2",
        },
    )
    assert response.status_code == 400
    assert "already registered" in response.json()["detail"]


@pytest.mark.asyncio
async def test_webauthn_register_without_begin(client: AsyncClient):
    """Complete without begin should fail (no challenge)."""
    headers = await register_and_get_token(client)

    response = await client.post(
        "/auth/webauthn/register/complete",
        headers=headers,
        json={
            "credential_id": "no-begin-cred",
            "public_key": "pub-key",
        },
    )
    assert response.status_code == 400
    assert "challenge" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_webauthn_login_flow(client: AsyncClient):
    """Full WebAuthn login flow: register then login."""
    headers = await register_and_get_token(client)

    # Register a credential
    await client.post("/auth/webauthn/register/begin", headers=headers)
    reg_resp = await client.post(
        "/auth/webauthn/register/complete",
        headers=headers,
        json={
            "credential_id": "login-test-cred",
            "public_key": "login-test-pub-key",
            "device_name": "Test Device",
        },
    )
    assert reg_resp.status_code == 200

    # Login with the credential
    login_resp = await client.post(
        "/auth/webauthn/login",
        json={
            "credential_id": "login-test-cred",
            "authenticator_data": "dGVzdC1hdXRoLWRhdGE=",
            "client_data_json": "dGVzdC1jbGllbnQtZGF0YQ==",
            "signature": "dGVzdC1zaWduYXR1cmU=",
        },
    )
    assert login_resp.status_code == 200
    data = login_resp.json()
    assert "user" in data
    assert "tokens" in data
    assert data["tokens"]["access_token"]
    assert data["tokens"]["refresh_token"]


@pytest.mark.asyncio
async def test_webauthn_login_unknown_credential(client: AsyncClient):
    """Login with unknown credential should fail."""
    response = await client.post(
        "/auth/webauthn/login",
        json={
            "credential_id": "nonexistent-cred",
            "authenticator_data": "data",
            "client_data_json": "data",
            "signature": "sig",
        },
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_list_webauthn_credentials(client: AsyncClient):
    """List credentials should return registered devices."""
    headers = await register_and_get_token(client)

    # Register two credentials
    for i in range(2):
        await client.post(
            "/auth/webauthn/register/begin", headers=headers
        )
        await client.post(
            "/auth/webauthn/register/complete",
            headers=headers,
            json={
                "credential_id": f"list-cred-{i}",
                "public_key": f"pub-key-{i}",
                "device_name": f"Device {i}",
            },
        )

    # List credentials
    response = await client.get(
        "/auth/webauthn/credentials", headers=headers
    )
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


@pytest.mark.asyncio
async def test_list_webauthn_credentials_empty(client: AsyncClient):
    """List credentials for user with none should return empty list."""
    headers = await register_and_get_token(client)

    response = await client.get(
        "/auth/webauthn/credentials", headers=headers
    )
    assert response.status_code == 200
    assert response.json() == []
