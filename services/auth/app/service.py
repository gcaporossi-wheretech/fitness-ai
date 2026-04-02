"""Auth business logic: user registration, login, token management."""

from __future__ import annotations

import hashlib
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import RefreshToken, User
from app.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)


class AuthServiceError(Exception):
    """Base exception for auth service errors."""

    def __init__(self, message: str, code: str) -> None:
        self.message = message
        self.code = code
        super().__init__(message)


class EmailAlreadyExistsError(AuthServiceError):
    """Raised when trying to register with an existing email."""

    def __init__(self) -> None:
        super().__init__("Email already registered", "EMAIL_EXISTS")


class InvalidCredentialsError(AuthServiceError):
    """Raised when login credentials are invalid."""

    def __init__(self) -> None:
        super().__init__("Invalid email or password", "INVALID_CREDENTIALS")


class InvalidRefreshTokenError(AuthServiceError):
    """Raised when refresh token is invalid or expired."""

    def __init__(self) -> None:
        super().__init__("Invalid or expired refresh token", "INVALID_REFRESH_TOKEN")


class UserNotFoundError(AuthServiceError):
    """Raised when user is not found."""

    def __init__(self) -> None:
        super().__init__("User not found", "USER_NOT_FOUND")


class InsufficientCreditsError(AuthServiceError):
    """Raised when user does not have enough AI credits."""

    def __init__(self) -> None:
        super().__init__("Insufficient AI credits", "INSUFFICIENT_CREDITS")


class AuthService:
    """Handles all authentication and user management operations."""

    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def register(
        self, email: str, password: str, name: str | None, language: str
    ) -> tuple[User, str, str]:
        """Register a new user account.

        Args:
            email: User email address.
            password: Plain text password (will be hashed).
            name: Optional display name.
            language: Preferred language code ('it' or 'en').

        Returns:
            Tuple of (user, access_token, refresh_token).

        Raises:
            EmailAlreadyExistsError: If email is already registered.
        """
        existing = await self.db.execute(select(User).where(User.email == email))
        if existing.scalar_one_or_none():
            raise EmailAlreadyExistsError()

        user = User(
            email=email,
            password_hash=hash_password(password),
            name=name,
            language=language,
        )
        self.db.add(user)
        await self.db.flush()

        access_token = create_access_token(str(user.id))
        raw_refresh, token_hash = create_refresh_token()
        refresh_token_record = RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=datetime.now(UTC)
            + timedelta(days=settings.jwt_refresh_expiry_days),
        )
        self.db.add(refresh_token_record)
        await self.db.commit()
        await self.db.refresh(user)

        return user, access_token, raw_refresh

    async def login(self, email: str, password: str) -> tuple[User, str, str]:
        """Authenticate user with email and password.

        Args:
            email: User email address.
            password: Plain text password to verify.

        Returns:
            Tuple of (user, access_token, refresh_token).

        Raises:
            InvalidCredentialsError: If email not found or password wrong.
        """
        result = await self.db.execute(
            select(User).where(User.email == email, User.is_active == True)
        )
        user = result.scalar_one_or_none()
        if not user or not verify_password(password, user.password_hash):
            raise InvalidCredentialsError()

        access_token = create_access_token(str(user.id))
        raw_refresh, token_hash = create_refresh_token()
        refresh_token_record = RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=datetime.now(UTC)
            + timedelta(days=settings.jwt_refresh_expiry_days),
        )
        self.db.add(refresh_token_record)

        # Clean up expired tokens for this user
        expired = await self.db.execute(
            select(RefreshToken).where(
                RefreshToken.user_id == user.id,
                RefreshToken.expires_at < datetime.now(UTC),
            )
        )
        for token in expired.scalars().all():
            await self.db.delete(token)

        await self.db.commit()
        return user, access_token, raw_refresh

    async def refresh_tokens(self, refresh_token: str) -> tuple[User, str, str]:
        """Exchange a valid refresh token for new access + refresh tokens.

        Args:
            refresh_token: The raw refresh token string.

        Returns:
            Tuple of (user, new_access_token, new_refresh_token).

        Raises:
            InvalidRefreshTokenError: If token is invalid or expired.
        """
        token_hash = hashlib.sha256(refresh_token.encode()).hexdigest()
        result = await self.db.execute(
            select(RefreshToken).where(
                RefreshToken.token_hash == token_hash,
                RefreshToken.expires_at > datetime.now(UTC),
            )
        )
        token_record = result.scalar_one_or_none()
        if not token_record:
            raise InvalidRefreshTokenError()

        # Delete old token (rotation)
        await self.db.delete(token_record)

        # Load user
        user_result = await self.db.execute(select(User).where(User.id == token_record.user_id))
        user = user_result.scalar_one_or_none()
        if not user or not user.is_active:
            raise InvalidRefreshTokenError()

        # Create new tokens
        access_token = create_access_token(str(user.id))
        raw_refresh, new_hash = create_refresh_token()
        new_token = RefreshToken(
            user_id=user.id,
            token_hash=new_hash,
            expires_at=datetime.now(UTC)
            + timedelta(days=settings.jwt_refresh_expiry_days),
        )
        self.db.add(new_token)
        await self.db.commit()

        return user, access_token, raw_refresh

    async def get_user_by_id(self, user_id: uuid.UUID) -> User:
        """Fetch a user by their UUID.

        Args:
            user_id: The user UUID.

        Returns:
            User object.

        Raises:
            UserNotFoundError: If user does not exist.
        """
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise UserNotFoundError()
        return user

    async def update_profile(self, user_id: uuid.UUID, **kwargs) -> User:
        """Update user profile fields.

        Args:
            user_id: The user UUID.
            **kwargs: Fields to update (name, age, goals, limitations, language).

        Returns:
            Updated user object.

        Raises:
            UserNotFoundError: If user does not exist.
        """
        user = await self.get_user_by_id(user_id)
        for key, value in kwargs.items():
            if value is not None and hasattr(user, key):
                setattr(user, key, value)
        user.updated_at = datetime.now(UTC)
        await self.db.commit()
        await self.db.refresh(user)
        return user

    async def get_credits(self, user_id: uuid.UUID) -> int:
        """Get AI credits balance for a user.

        Args:
            user_id: The user UUID.

        Returns:
            Current credits balance.
        """
        user = await self.get_user_by_id(user_id)
        return user.ai_credits

    async def deduct_credits(self, user_id: uuid.UUID, amount: int = 1) -> int:
        """Deduct AI credits from a user's balance.

        Args:
            user_id: The user UUID.
            amount: Number of credits to deduct.

        Returns:
            Remaining credits balance.

        Raises:
            InsufficientCreditsError: If user does not have enough credits.
        """
        user = await self.get_user_by_id(user_id)
        if user.ai_credits < amount:
            raise InsufficientCreditsError()
        user.ai_credits -= amount
        user.updated_at = datetime.now(UTC)
        await self.db.commit()
        await self.db.refresh(user)
        return user.ai_credits

    async def add_credits(self, user_id: uuid.UUID, amount: int) -> int:
        """Add AI credits to a user's balance.

        Args:
            user_id: The user UUID.
            amount: Number of credits to add.

        Returns:
            New credits balance.
        """
        user = await self.get_user_by_id(user_id)
        user.ai_credits += amount
        user.updated_at = datetime.now(UTC)
        await self.db.commit()
        await self.db.refresh(user)
        return user.ai_credits
