"""FastAPI dependencies for AI service: JWT verification, current user extraction."""

from __future__ import annotations

import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import settings

security_scheme = HTTPBearer()


def decode_access_token(token: str) -> dict | None:
    """Decode and validate a JWT access token using shared secret.

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


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
) -> uuid.UUID:
    """Extract the current user ID from JWT token.

    Args:
        credentials: Bearer token from Authorization header.

    Returns:
        User UUID from the JWT payload.

    Raises:
        HTTPException: 401 if token is invalid or user_id cannot be parsed.
    """
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        return uuid.UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        ) from exc
