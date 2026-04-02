"""Auth API router: registration, login, token refresh, profile management."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.dependencies import get_current_user
from app.schemas import (
    AuthResponse,
    CreditsResponse,
    TokenRefreshRequest,
    TokenResponse,
    UserLoginRequest,
    UserProfileUpdate,
    UserRegisterRequest,
    UserResponse,
)
from app.service import (
    AuthService,
    EmailAlreadyExistsError,
    InvalidCredentialsError,
    InvalidRefreshTokenError,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(request: UserRegisterRequest, db: AsyncSession = Depends(get_db)) -> AuthResponse:
    """Register a new user account.

    Args:
        request: Registration data (email, password, name, language).
        db: Database session.

    Returns:
        User data with authentication tokens.
    """
    service = AuthService(db)
    try:
        user, access_token, refresh_token = await service.register(
            email=request.email,
            password=request.password,
            name=request.name,
            language=request.language,
        )
    except EmailAlreadyExistsError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=exc.message,
        ) from exc

    return AuthResponse(
        user=UserResponse.model_validate(user),
        tokens=TokenResponse(access_token=access_token, refresh_token=refresh_token),
    )


@router.post("/login", response_model=AuthResponse)
async def login(request: UserLoginRequest, db: AsyncSession = Depends(get_db)) -> AuthResponse:
    """Authenticate with email and password.

    Args:
        request: Login credentials.
        db: Database session.

    Returns:
        User data with authentication tokens.
    """
    service = AuthService(db)
    try:
        user, access_token, refresh_token = await service.login(
            email=request.email,
            password=request.password,
        )
    except InvalidCredentialsError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=exc.message,
        ) from exc

    return AuthResponse(
        user=UserResponse.model_validate(user),
        tokens=TokenResponse(access_token=access_token, refresh_token=refresh_token),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_tokens(request: TokenRefreshRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    """Exchange refresh token for new access + refresh tokens.

    Args:
        request: Refresh token.
        db: Database session.

    Returns:
        New token pair.
    """
    service = AuthService(db)
    try:
        _user, access_token, refresh_token = await service.refresh_tokens(request.refresh_token)
    except InvalidRefreshTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=exc.message,
        ) from exc

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.get("/me", response_model=UserResponse)
async def get_profile(current_user: User = Depends(get_current_user)) -> UserResponse:
    """Get the current authenticated user profile.

    Args:
        current_user: Authenticated user from JWT.

    Returns:
        User profile data.
    """
    return UserResponse.model_validate(current_user)


@router.patch("/me", response_model=UserResponse)
async def update_profile(
    request: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    """Update current user profile.

    Args:
        request: Fields to update.
        current_user: Authenticated user from JWT.
        db: Database session.

    Returns:
        Updated user profile.
    """
    service = AuthService(db)
    update_data = request.model_dump(exclude_unset=True)
    user = await service.update_profile(current_user.id, **update_data)
    return UserResponse.model_validate(user)


@router.get("/credits", response_model=CreditsResponse)
async def get_credits(current_user: User = Depends(get_current_user)) -> CreditsResponse:
    """Get current AI credits balance.

    Args:
        current_user: Authenticated user from JWT.

    Returns:
        Credits balance.
    """
    return CreditsResponse(credits=current_user.ai_credits)
