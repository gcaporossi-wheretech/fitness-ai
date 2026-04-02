# Logging and Observability Rules
Applies to: services/**/*.py, web/**/*.ts

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
- Every service exposes GET /health returning {"status": "ok", "service": "<name>", "version": "x.y.z"}
- Health check includes dependency checks (db connection, Redis, Claude API)
- Docker HEALTHCHECK configured in every Dockerfile
- Traefik routes only to healthy containers

## Correlation
- Every incoming request gets a UUID correlation_id
- correlation_id propagated through all internal calls and logs
- Traefik forwards X-Correlation-Id header
- Client sends correlation_id header for sync operations

## Monitoring
- Traefik dashboard for HTTP routing metrics
- Redis: INFO command for memory and connection stats
- PostgreSQL: pg_stat_statements for slow query analysis
- CloudWatch Logs: one log group per service
