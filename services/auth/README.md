# Auth Service

Authentication, user management, and AI credits for FitnessAI.

## Responsibilities
- User registration (email + password)
- Login and JWT management (access 15min + refresh 7d)
- WebAuthn/Face ID (future)
- User profile CRUD
- AI credits balance

## Run locally
```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
```

## Run tests
```bash
pip install -r requirements-dev.txt
pytest -v --cov=app
```

## API Endpoints
- POST /auth/register
- POST /auth/login
- POST /auth/refresh
- GET /auth/me
- PATCH /auth/me
- GET /auth/credits
- GET /health
