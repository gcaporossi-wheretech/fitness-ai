# Python API Rules
Applies to: api/**/*.py

## Structure
- Every module in `api/modules/` has: `router.py`, `models.py`, `service.py`, `schemas.py`
- Router handles HTTP only — business logic in service.py
- Pydantic v2 for all request/response schemas with explicit examples
- Type hints on every function signature (params + return)

## Code style
- Async functions for all endpoints and DB operations
- Use `from __future__ import annotations` in every file
- Docstring on every public function: one-line summary + Args + Returns
- Error responses use `HTTPException` with meaningful detail messages
- Never catch generic `Exception` — catch specific exceptions

## Security
- Never hardcode secrets — use `os.environ` or pydantic `Settings`
- All user input validated via Pydantic schema before processing
- SQL queries use parameterized statements — never f-strings
- JWT tokens have expiration, refresh flow documented
- Rate limiting on AI endpoints (expensive API calls)

## Testing
- Every `service.py` has a corresponding `test_service.py`
- Every `router.py` has a corresponding `test_router.py` with httpx AsyncClient
- Test names: `test_<function>_<scenario>` (e.g., `test_login_invalid_password`)
- Use pytest fixtures for DB setup/teardown
