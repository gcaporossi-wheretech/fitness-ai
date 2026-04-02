# AI Service

Vision scan, Coach generation, and prompt engineering for FitnessAI.

## Responsibilities
- Equipment recognition from photo (AI Vision via Claude API)
- Personalized workout plan from body photos (AI Coach)
- Result caching via Redis (hash-based dedup)
- Async job processing via Redis Streams
- Credits management (deduct per AI call)

## Run locally
```bash
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8003 --reload
```

## Run tests
```bash
pip install -r requirements-dev.txt
pytest -v --cov=app
```

## API Endpoints (planned)
- POST /ai/vision/scan
- POST /ai/coach/generate
- GET /ai/vision/history
- GET /ai/coach/history
- GET /health
