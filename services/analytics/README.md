# Analytics Service

Progression tracking, volume analytics, and adherence reports for FitnessAI.

## Responsibilities
- Progression tracking per exercise (weight over time)
- Volume analytics per muscle group
- Training adherence calculation
- Summary reports (weekly/monthly)

## Run locally
```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8004 --reload
```

## Run tests
```bash
pip install -r requirements-dev.txt
pytest -v --cov=app
```

## API Endpoints (planned)
- GET /analytics/progress/{exercise_id}
- GET /analytics/volume
- GET /analytics/adherence
- GET /analytics/summary
- GET /health
