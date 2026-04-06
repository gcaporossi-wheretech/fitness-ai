"""Auth API router: registration, login, token refresh, profile management."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models import User
from app.schemas import (
    AccountDeleteRequest,
    AuthResponse,
    CreditsResponse,
    TokenRefreshRequest,
    TokenResponse,
    UserLoginRequest,
    UserProfileUpdate,
    UserRegisterRequest,
    UserResponse,
    WebAuthnCredentialResponse,
    WebAuthnLoginRequest,
    WebAuthnRegisterRequest,
    WebAuthnRegisterResponse,
)
from app.service import (
    AuthService,
    EmailAlreadyExistsError,
    InsufficientCreditsError,
    InvalidCredentialsError,
    InvalidRefreshTokenError,
    WebAuthnError,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    request: UserRegisterRequest, db: AsyncSession = Depends(get_db)
) -> AuthResponse:
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
async def refresh_tokens(
    request: TokenRefreshRequest, db: AsyncSession = Depends(get_db)
) -> TokenResponse:
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


@router.post("/credits/deduct", response_model=CreditsResponse)
async def deduct_credits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CreditsResponse:
    """Deduct one AI credit from the user's balance.

    Used internally when an AI operation is performed.

    Args:
        current_user: Authenticated user from JWT.
        db: Database session.

    Returns:
        Updated credits balance.
    """
    service = AuthService(db)
    try:
        remaining = await service.deduct_credits(current_user.id)
    except InsufficientCreditsError as exc:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=exc.message,
        ) from exc
    return CreditsResponse(credits=remaining)


# ============================================================
# GDPR: Data Export & Account Deletion
# ============================================================


@router.get("/me/export")
async def export_user_data(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Export all user data for GDPR compliance.

    Returns a complete JSON document with profile, credentials,
    workout plans, sessions, and AI scan history.

    Args:
        current_user: Authenticated user from JWT.
        db: Database session.

    Returns:
        Complete user data export.
    """
    service = AuthService(db)
    return await service.export_user_data(current_user.id)


@router.delete("/me", status_code=204)
async def delete_account(
    request: AccountDeleteRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Delete user account and all associated data (GDPR right to erasure).

    Requires password confirmation for security.
    CASCADE deletes all auth-owned data. Cross-schema data
    (workouts, AI) deleted explicitly.

    Args:
        request: Password confirmation.
        current_user: Authenticated user from JWT.
        db: Database session.
    """
    service = AuthService(db)
    try:
        await service.delete_account(current_user.id, request.password)
    except InvalidCredentialsError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
        ) from exc


# ============================================================
# WebAuthn endpoints
# ============================================================


@router.post("/webauthn/register/begin", response_model=WebAuthnRegisterResponse)
async def webauthn_register_begin(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WebAuthnRegisterResponse:
    """Begin WebAuthn credential registration (generate challenge).

    Args:
        current_user: Authenticated user from JWT.
        db: Database session.

    Returns:
        Registration options with challenge (60s timeout).
    """
    service = AuthService(db)
    options = await service.webauthn_begin_register(current_user.id)
    return WebAuthnRegisterResponse(**options)


@router.post("/webauthn/register/complete", response_model=WebAuthnCredentialResponse)
async def webauthn_register_complete(
    request: WebAuthnRegisterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WebAuthnCredentialResponse:
    """Complete WebAuthn credential registration (store credential).

    Args:
        request: Credential data from authenticator.
        current_user: Authenticated user from JWT.
        db: Database session.

    Returns:
        The registered credential details.
    """
    service = AuthService(db)
    try:
        credential = await service.webauthn_complete_register(
            user_id=current_user.id,
            credential_id=request.credential_id,
            public_key=request.public_key,
            device_name=request.device_name,
        )
    except WebAuthnError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=exc.message,
        ) from exc
    return WebAuthnCredentialResponse.model_validate(credential)


@router.post("/webauthn/login", response_model=AuthResponse)
async def webauthn_login(
    request: WebAuthnLoginRequest,
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """Authenticate via WebAuthn (Face ID / passkey).

    Two-step flow: client first calls begin (not needed for simplified flow),
    then sends credential assertion to this endpoint.

    Args:
        request: WebAuthn assertion data.
        db: Database session.

    Returns:
        User data with authentication tokens.
    """
    service = AuthService(db)
    try:
        # Begin + complete in one step for simplified mobile flow
        await service.webauthn_begin_login(request.credential_id)
        user, access_token, refresh_token = await service.webauthn_complete_login(
            credential_id=request.credential_id,
            authenticator_data=request.authenticator_data,
            client_data_json=request.client_data_json,
            signature=request.signature,
        )
    except WebAuthnError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=exc.message,
        ) from exc

    return AuthResponse(
        user=UserResponse.model_validate(user),
        tokens=TokenResponse(access_token=access_token, refresh_token=refresh_token),
    )


@router.get("/webauthn/credentials", response_model=list[WebAuthnCredentialResponse])
async def list_webauthn_credentials(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[WebAuthnCredentialResponse]:
    """List all WebAuthn credentials for the current user.

    Args:
        current_user: Authenticated user from JWT.
        db: Database session.

    Returns:
        List of registered credentials.
    """
    service = AuthService(db)
    credentials = await service.list_webauthn_credentials(current_user.id)
    return [WebAuthnCredentialResponse.model_validate(c) for c in credentials]
