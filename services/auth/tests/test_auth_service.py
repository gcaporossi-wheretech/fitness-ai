"""Unit tests for auth service business logic."""

from __future__ import annotations

from app.security import create_access_token, decode_access_token, hash_password, verify_password


class TestPasswordHashing:
    """Tests for password hash/verify functions."""

    def test_hash_password_returns_hash(self):
        """Hashing a password should return a bcrypt hash string."""
        hashed = hash_password("TestPass123")
        assert hashed != "TestPass123"
        assert hashed.startswith("$2b$")

    def test_verify_correct_password(self):
        """Verifying correct password should return True."""
        hashed = hash_password("TestPass123")
        assert verify_password("TestPass123", hashed) is True

    def test_verify_wrong_password(self):
        """Verifying wrong password should return False."""
        hashed = hash_password("TestPass123")
        assert verify_password("WrongPass", hashed) is False


class TestJWTTokens:
    """Tests for JWT creation and decoding."""

    def test_create_and_decode_access_token(self):
        """Created token should decode to original user_id."""
        user_id = "550e8400-e29b-41d4-a716-446655440000"
        token = create_access_token(user_id)
        payload = decode_access_token(token)
        assert payload is not None
        assert payload["sub"] == user_id
        assert payload["type"] == "access"

    def test_decode_invalid_token_returns_none(self):
        """Invalid token should return None."""
        assert decode_access_token("invalid.token.here") is None

    def test_decode_empty_token_returns_none(self):
        """Empty string should return None."""
        assert decode_access_token("") is None
