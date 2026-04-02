# Workouts Service

Workout plans, sessions, exercise database, and offline sync for FitnessAI.

## Responsibilities
- CRUD workout plans
- Workout session tracking
- Exercise database with seed data
- Offline-first sync (batch upload, last-write-wins)

## Run locally
```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
```

## Run tests
```bash
pip install -r requirements-dev.txt
pytest -v --cov=app
```

## API Endpoints (planned)
- GET/POST /workouts/plans
- GET/PATCH/DELETE /workouts/plans/{id}
- GET/POST /workouts/sessions
- POST /workouts/sync
- GET /workouts/exercises
- GET /health
