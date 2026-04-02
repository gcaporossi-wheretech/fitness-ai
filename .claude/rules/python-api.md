# Python API Rules
Applies to: services/**/*.py

## Structure
- Every microservice in `services/<name>/` has: `app/main.py`, `app/router.py`, `app/service.py`, `app/schemas.py`, `app/models.py`, `app/config.py`, `app/database.py`
- Router handles HTTP only — business logic in service.py
- Pydantic v2 for all request/response schemas with explicit examples
- Type hints on every function signature (params + return)
- Each service is a standalone FastAPI app with its own Dockerfile

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
- JWT tokens validated locally in each service (shared secret)
- Rate limiting on AI endpoints (expensive API calls) via Traefik + app

## Testing
- Every `service.py` has a corresponding `tests/test_service.py`
- Every `router.py` has a corresponding `tests/test_router.py` with httpx AsyncClient
- Test names: `test_<function>_<scenario>` (e.g., `test_login_invalid_password`)
- Use pytest fixtures for DB setup/teardown
- Tests run from service directory: `cd services/<name> && pytest`

## Cross-service
- Services do NOT import from each other
- User identity comes from JWT (shared secret validation)
- No physical FK between service schemas — logical references only
- If a service needs data from another, use HTTP call or shared DB read (documented)
