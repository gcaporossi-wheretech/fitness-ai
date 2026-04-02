"""Security utilities: JWT token creation/verification, password hashing."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from uuid import uuid4

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto", bcrypt__rounds=12)


def hash_password(password: str) -> str:
    """Hash a password using bcrypt with cost factor 12."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its bcrypt hash."""
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(user_id: str) -> str:
    """Create a JWT access token with short expiration.

    Args:
        user_id: The user UUID to encode in the token.

    Returns:
        Encoded JWT string.
    """
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_access_expiry_minutes)
    payload = {
        "sub": user_id,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "access",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token() -> tuple[str, str]:
    """Create a refresh token (raw UUID) and its SHA256 hash for storage.

    Returns:
        Tuple of (raw_token, token_hash).
    """
    import hashlib

    raw_token = str(uuid4())
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    return raw_token, token_hash


def decode_access_token(token: str) -> dict | None:
    """Decode and validate a JWT access token.

    Args:
        token: The JWT string to decode.

    Returns:
        Token payload dict or None if invalid/expired.
    """
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        if payload.get("type") != "access":
            return None
        return payload
    except JWTError:
        return None
