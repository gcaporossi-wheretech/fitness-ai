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
- Named volumes for persistent data (db)
- Restart policy: `unless-stopped` for all services
- Resource limits defined for each service

## Database
- Alembic for all schema migrations — never manual DDL
- Every migration MUST be reversible (upgrade + downgrade)
- Backup strategy: daily pg_dump to S3
- Connection pooling via asyncpg

## Nginx
- HTTPS with Let's Encrypt certificates (certbot)
- Security headers: HSTS, X-Frame-Options, CSP, X-Content-Type-Options
- Rate limiting configured per endpoint category
- Gzip compression enabled
- Proxy pass to api and web containers by service name
