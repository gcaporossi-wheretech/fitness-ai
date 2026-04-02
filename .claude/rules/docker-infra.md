# Docker and Infrastructure Rules
Applies to: **/Dockerfile*, **/docker-compose*, infra/**

## Docker images
- Always use specific version tags — never `:latest`
- Multi-stage builds to minimize image size
- Non-root user in every container
- HEALTHCHECK in every Dockerfile
- .dockerignore in every service directory

## Docker Compose
- All services in one docker-compose.yml at repo root
- Environment variables via .env file (not hardcoded in yml)
- Named volumes for persistent data (db, redis)
- Restart policy: `unless-stopped` for all services
- Docker network `fitnessai` for all containers

## Database
- Alembic for all schema migrations — never manual DDL
- Every migration MUST be reversible (upgrade + downgrade)
- Each service owns its own PostgreSQL schema (auth.*, workouts.*, ai.*)
- No cross-schema FK constraints — use logical references via user_id from JWT
- Backup strategy: daily pg_dump to S3

## Redis
- Append-only persistence enabled
- Max memory 256MB with allkeys-lru eviction
- AI cache keys: `ai:vision:{hash}` and `ai:coach:{hash}` with TTL
- Streams for async jobs: `ai:jobs` stream with consumer groups

## Traefik (API Gateway)
- Traefik v3 with Docker provider for auto-discovery
- Path-based routing via Docker labels on each service
- Rate limiting via dynamic.yml middlewares
- Security headers (HSTS, X-Frame-Options, CSP) via middleware
- HTTPS with Let's Encrypt ACME in production
- Dashboard enabled only in development (disable in production)
