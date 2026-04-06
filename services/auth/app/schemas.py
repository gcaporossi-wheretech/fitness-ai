"""Pydantic v2 schemas for auth service request/response validation."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field, field_validator


class UserRegisterRequest(BaseModel):
    """Schema for user registration request."""

    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    name: str | None = Field(None, max_length=100)
    language: str = Field("it", pattern="^(it|en)$")

    @field_validator("password")
    @classmethod
    def password_complexity(cls, v: str) -> str:
        """Validate password has at least one letter and one digit."""
        if not any(c.isalpha() for c in v):
            msg = "Password must contain at least one letter"
            raise ValueError(msg)
        if not any(c.isdigit() for c in v):
            msg = "Password must contain at least one digit"
            raise ValueError(msg)
        return v


class UserLoginRequest(BaseModel):
    """Schema for user login request."""

    email: EmailStr
    password: str


class TokenRefreshRequest(BaseModel):
    """Schema for token refresh request."""

    refresh_token: str


class UserProfileUpdate(BaseModel):
    """Schema for partial profile update."""

    name: str | None = Field(None, max_length=100)
    age: int | None = Field(None, ge=13, le=120)
    goals: dict | None = None
    limitations: dict | None = None
    language: str | None = Field(None, pattern="^(it|en)$")


class UserResponse(BaseModel):
    """Schema for user data in responses."""

    id: uuid.UUID
    email: str
    name: str | None
    age: int | None
    goals: dict | None
    limitations: dict | None
    ai_credits: int
    language: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    """Schema for authentication token response."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthResponse(BaseModel):
    """Schema combining user data with tokens after login/register."""

    user: UserResponse
    tokens: TokenResponse


class CreditsResponse(BaseModel):
    """Schema for AI credits balance."""

    credits: int


# ============================================================
# WebAuthn
# ============================================================


class AccountDeleteRequest(BaseModel):
    """Schema for account deletion request (GDPR)."""

    password: str = Field(min_length=1, description="Password confirmation")


class WebAuthnRegisterRequest(BaseModel):
    """Schema for WebAuthn credential registration."""

    credential_id: str = Field(min_length=1, max_length=512)
    public_key: str = Field(min_length=1, max_length=2048)
    device_name: str | None = Field(None, max_length=255)


class WebAuthnRegisterResponse(BaseModel):
    """Response for WebAuthn registration: includes challenge."""

    challenge: str
    rp_id: str = "fitnessai.app"
    rp_name: str = "FitnessAI"
    user_id: str
    user_name: str
    timeout: int = 60000


class WebAuthnLoginRequest(BaseModel):
    """Schema for WebAuthn login."""

    credential_id: str
    authenticator_data: str
    client_data_json: str
    signature: str


class WebAuthnCredentialResponse(BaseModel):
    """Schema for a stored WebAuthn credential."""

    id: uuid.UUID
    credential_id: str
    device_name: str | None
    created_at: datetime

    model_config = {"from_attributes": True}
