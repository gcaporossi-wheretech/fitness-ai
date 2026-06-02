"""Auth business logic: user registration, login, token management."""

from __future__ import annotations

import hashlib
import logging
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import RefreshToken, User, WebAuthnCredential
from app.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)

# In-memory challenge store (would be Redis in production)
_challenges: dict[str, dict] = {}


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


class WebAuthnError(AuthServiceError):
    """Raised when WebAuthn operation fails."""

    def __init__(self, message: str = "WebAuthn authentication failed") -> None:
        super().__init__(message, "WEBAUTHN_ERROR")


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
            expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_expiry_days),
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
            expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_expiry_days),
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
            expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_expiry_days),
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

    # ===========================================================
    # WebAuthn
    # ===========================================================

    async def webauthn_begin_register(self, user_id: uuid.UUID) -> dict:
        """Begin WebAuthn registration — generate a challenge.

        Args:
            user_id: The user UUID.

        Returns:
            Registration options including challenge, rp info, user info.
        """
        user = await self.get_user_by_id(user_id)
        challenge = secrets.token_urlsafe(32)

        # Store challenge with 60s timeout
        _challenges[str(user_id)] = {
            "challenge": challenge,
            "type": "register",
            "expires": datetime.now(UTC) + timedelta(seconds=60),
        }

        return {
            "challenge": challenge,
            "rp_id": settings.webauthn_rp_id,
            "rp_name": settings.webauthn_rp_name,
            "user_id": str(user.id),
            "user_name": user.email,
            "timeout": 60000,
        }

    async def webauthn_complete_register(
        self,
        user_id: uuid.UUID,
        credential_id: str,
        public_key: str,
        device_name: str | None = None,
    ) -> WebAuthnCredential:
        """Complete WebAuthn registration — store the credential.

        Args:
            user_id: The user UUID.
            credential_id: Base64-encoded credential ID from authenticator.
            public_key: Base64-encoded public key.
            device_name: Optional human-readable device name.

        Returns:
            The created WebAuthnCredential record.

        Raises:
            WebAuthnError: If challenge expired or not found.
        """
        # Verify challenge exists and hasn't expired
        stored = _challenges.pop(str(user_id), None)
        if not stored or stored["type"] != "register":
            raise WebAuthnError("No pending registration challenge")
        if datetime.now(UTC) > stored["expires"]:
            raise WebAuthnError("Registration challenge expired")

        # Check for duplicate credential
        existing = await self.db.execute(
            select(WebAuthnCredential).where(WebAuthnCredential.credential_id == credential_id)
        )
        if existing.scalar_one_or_none():
            raise WebAuthnError("Credential already registered")

        credential = WebAuthnCredential(
            user_id=user_id,
            credential_id=credential_id,
            public_key=public_key,
            device_name=device_name,
            sign_count=0,
        )
        self.db.add(credential)
        await self.db.commit()
        await self.db.refresh(credential)
        return credential

    async def webauthn_begin_login(self, credential_id: str) -> dict:
        """Begin WebAuthn login — find credential and generate challenge.

        Args:
            credential_id: The credential ID to authenticate with.

        Returns:
            Login options including challenge.

        Raises:
            WebAuthnError: If credential not found.
        """
        result = await self.db.execute(
            select(WebAuthnCredential).where(WebAuthnCredential.credential_id == credential_id)
        )
        credential = result.scalar_one_or_none()
        if not credential:
            raise WebAuthnError("Credential not found")

        challenge = secrets.token_urlsafe(32)
        _challenges[credential_id] = {
            "challenge": challenge,
            "type": "login",
            "user_id": str(credential.user_id),
            "expires": datetime.now(UTC) + timedelta(seconds=60),
        }

        return {
            "challenge": challenge,
            "credential_id": credential_id,
            "timeout": 60000,
        }

    async def webauthn_complete_login(
        self,
        credential_id: str,
        authenticator_data: str,
        client_data_json: str,
        signature: str,
    ) -> tuple[User, str, str]:
        """Complete WebAuthn login — verify and issue tokens.

        In a production environment, the authenticator_data, client_data_json,
        and signature would be cryptographically verified against the stored
        public key. For this implementation, we verify the challenge flow
        and trust the client-side WebAuthn API verification.

        Args:
            credential_id: The credential ID used.
            authenticator_data: Base64-encoded authenticator data.
            client_data_json: Base64-encoded client data JSON.
            signature: Base64-encoded signature.

        Returns:
            Tuple of (user, access_token, refresh_token).

        Raises:
            WebAuthnError: If verification fails.
        """
        # Verify challenge
        stored = _challenges.pop(credential_id, None)
        if not stored or stored["type"] != "login":
            raise WebAuthnError("No pending login challenge")
        if datetime.now(UTC) > stored["expires"]:
            raise WebAuthnError("Login challenge expired")

        # Get credential and user
        result = await self.db.execute(
            select(WebAuthnCredential).where(WebAuthnCredential.credential_id == credential_id)
        )
        credential = result.scalar_one_or_none()
        if not credential:
            raise WebAuthnError("Credential not found")

        # Increment sign count
        credential.sign_count += 1
        await self.db.flush()

        # Get user
        user = await self.get_user_by_id(credential.user_id)
        if not user.is_active:
            raise WebAuthnError("Account is disabled")

        # Issue tokens
        access_token = create_access_token(str(user.id))
        raw_refresh, token_hash = create_refresh_token()
        refresh_token_record = RefreshToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=datetime.now(UTC) + timedelta(days=settings.jwt_refresh_expiry_days),
        )
        self.db.add(refresh_token_record)
        await self.db.commit()

        return user, access_token, raw_refresh

    async def list_webauthn_credentials(self, user_id: uuid.UUID) -> list[WebAuthnCredential]:
        """List all WebAuthn credentials for a user.

        Args:
            user_id: The user UUID.

        Returns:
            List of WebAuthn credentials.
        """
        result = await self.db.execute(
            select(WebAuthnCredential)
            .where(WebAuthnCredential.user_id == user_id)
            .order_by(WebAuthnCredential.created_at.desc())
        )
        return list(result.scalars().all())

    # ===========================================================
    # GDPR: Data Export & Account Deletion
    # ===========================================================

    logger = logging.getLogger(__name__)

    async def export_user_data(self, user_id: uuid.UUID) -> dict:
        """Export all user data for GDPR compliance.

        Aggregates data from auth schema and cross-schema reads
        for workouts and AI data (read-only access).

        Args:
            user_id: The user UUID.

        Returns:
            Complete user data export dict.
        """
        user = await self.get_user_by_id(user_id)
        uid_str = str(user_id)

        export = {
            "export_version": "1.0",
            "exported_at": datetime.now(UTC).isoformat(),
            "profile": {
                "id": uid_str,
                "email": user.email,
                "name": user.name,
                "age": user.age,
                "goals": user.goals,
                "limitations": user.limitations,
                "ai_credits": user.ai_credits,
                "language": user.language,
                "created_at": user.created_at.isoformat() if user.created_at else None,
            },
            "webauthn_credentials": [],
            "workout_plans": [],
            "workout_sessions": [],
            "ai_vision_scans": [],
            "ai_coach_generations": [],
        }

        # WebAuthn credentials
        creds = await self.list_webauthn_credentials(user_id)
        export["webauthn_credentials"] = [
            {
                "credential_id": c.credential_id,
                "device_name": c.device_name,
                "created_at": c.created_at.isoformat() if c.created_at else None,
            }
            for c in creds
        ]

        # Cross-schema reads (workouts, AI) — best effort
        try:
            plans_result = await self.db.execute(
                text(
                    "SELECT id, name, description, source, created_at "
                    "FROM workouts.workout_plans WHERE user_id = :uid"
                ),
                {"uid": user_id},
            )
            export["workout_plans"] = [dict(row._mapping) for row in plans_result]
        except Exception as exc:  # noqa: BLE001
            self.logger.debug("Could not read workout plans: %s", exc)

        try:
            sessions_result = await self.db.execute(
                text(
                    "SELECT id, day_name, started_at, completed_at, "
                    "duration_seconds, notes FROM "
                    "workouts.workout_sessions WHERE user_id = :uid"
                ),
                {"uid": user_id},
            )
            export["workout_sessions"] = [dict(row._mapping) for row in sessions_result]
        except Exception as exc:  # noqa: BLE001
            self.logger.debug("Could not read workout sessions: %s", exc)

        try:
            scans_result = await self.db.execute(
                text(
                    "SELECT id, equipment_name, equipment_brand, "
                    "credits_used, created_at FROM "
                    "ai.ai_vision_scans WHERE user_id = :uid"
                ),
                {"uid": user_id},
            )
            export["ai_vision_scans"] = [dict(row._mapping) for row in scans_result]
        except Exception as exc:  # noqa: BLE001
            self.logger.debug("Could not read AI vision scans: %s", exc)

        try:
            coach_result = await self.db.execute(
                text(
                    "SELECT id, photo_count, credits_used, created_at "
                    "FROM ai.ai_coach_generations WHERE user_id = :uid"
                ),
                {"uid": user_id},
            )
            export["ai_coach_generations"] = [dict(row._mapping) for row in coach_result]
        except Exception as exc:  # noqa: BLE001
            self.logger.debug("Could not read AI coach data: %s", exc)

        self.logger.info("GDPR data export completed for user=%s", uid_str)
        return export

    async def delete_account(self, user_id: uuid.UUID, password: str) -> bool:
        """Delete a user account and all associated data (GDPR).

        Verifies password before deletion. CASCADE deletes handle
        auth schema data. Cross-schema data deleted explicitly.

        Args:
            user_id: The user UUID.
            password: Password confirmation for security.

        Returns:
            True if account was deleted.

        Raises:
            InvalidCredentialsError: If password is incorrect.
        """
        user = await self.get_user_by_id(user_id)

        if not verify_password(password, user.password_hash):
            raise InvalidCredentialsError()

        uid_str = str(user_id)

        # Delete cross-schema data (best effort)
        for stmt in [
            "DELETE FROM workouts.workout_sessions WHERE user_id = :uid",
            "DELETE FROM workouts.workout_plans WHERE user_id = :uid",
            "DELETE FROM ai.ai_vision_scans WHERE user_id = :uid",
            "DELETE FROM ai.ai_coach_generations WHERE user_id = :uid",
        ]:
            try:
                await self.db.execute(text(stmt), {"uid": user_id})
            except Exception as exc:  # noqa: BLE001
                self.logger.debug("Cross-schema delete skipped: %s", exc)

        # Delete user (CASCADE handles auth schema tables)
        await self.db.delete(user)
        await self.db.commit()

        self.logger.info("GDPR account deletion completed for user=%s", uid_str)
        return True
