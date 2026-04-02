# Skill: new-service

Scaffolds a new microservice inside services/ with the standard file structure. Use when the architecture requires a new independent service in the FitnessAI backend.

## Parameters
- service_name: snake_case name of the service (e.g., "notifications")
- port: port number for the service (e.g., 8005)

## Steps
1. Create directory `services/<service_name>/`
2. Create app/ directory with standard files:
   - `__init__.py` with service docstring
   - `main.py` with FastAPI app, health endpoint, CORS
   - `config.py` with Pydantic Settings (database_url, jwt_secret, service_name, service_port)
   - `router.py` with FastAPI APIRouter
   - `schemas.py` with Pydantic v2 request/response schemas
   - `models.py` with SQLAlchemy models using service-specific schema
   - `service.py` with business logic class
   - `dependencies.py` with JWT validation
   - `database.py` with engine and session factory
3. Create `Dockerfile` (multi-stage build, non-root user, healthcheck)
4. Create `requirements.txt` and `requirements-dev.txt`
5. Create `pyproject.toml` with ruff, pytest, coverage config
6. Create `.env.example`
7. Create `README.md`
8. Create `tests/` directory with `__init__.py` and `conftest.py`
9. Add service to `docker-compose.yml` with Traefik labels
10. Add service to CI pipeline matrix in `.github/workflows/ci.yml`
11. Update `docs/architecture/services.md` with new service entry
12. Update `docs/architecture/overview.md` container table
