# Logging and Observability Rules
Applies to: api/**/*.py, web/**/*.ts

## Log format
- Structured JSON for all backend logs
- Required fields: timestamp, level, service, correlation_id, message
- Optional fields: user_id, endpoint, duration_ms, error_type

## Log levels
- ERROR: unexpected failures, exceptions, data corruption
- WARNING: degraded performance, retries, rate limits hit
- INFO: request lifecycle, business events (login, workout completed)
- DEBUG: detailed flow, only in development

## Health checks
- Every container exposes GET /health returning {"status": "ok", "version": "x.y.z"}
- Health check includes dependency checks (db connection, Claude API reachable)
- Docker HEALTHCHECK configured in Dockerfile

## Correlation
- Every incoming request gets a UUID correlation_id
- correlation_id propagated through all internal calls and logs
- Client sends correlation_id header for sync operations
