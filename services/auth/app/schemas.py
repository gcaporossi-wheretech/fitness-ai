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
