# Skill: new-module

Scaffolds a new backend module inside api/modules/ with the standard file structure. Use when the architecture requires a new functional module in the FastAPI backend.

## Parameters
- module_name: snake_case name of the module (e.g., "notifications")

## Steps
1. Create directory `api/modules/<module_name>/`
2. Create standard files:
   - `__init__.py` with module docstring
   - `router.py` with FastAPI APIRouter and prefix
   - `models.py` with SQLAlchemy/asyncpg model stubs
   - `schemas.py` with Pydantic v2 request/response schemas
   - `service.py` with business logic class
3. Create test directory `api/tests/test_<module_name>/`
   - `test_service.py` with test class stub
   - `test_router.py` with httpx AsyncClient test stub
4. Register the router in `api/main.py`
5. Update docs/architecture/modules.md with new module entry
