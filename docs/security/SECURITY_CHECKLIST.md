# Security Hardening Checklist — FitnessAI

## Authentication & Authorization
- [x] JWT tokens with short expiry (15min access, 7d refresh)
- [x] Password hashing: bcrypt cost 12
- [x] Password complexity validation (8+ chars, letter + digit)
- [x] WebAuthn/passkey support for biometric auth
- [x] Each service validates JWT independently (shared secret)
- [x] Rate limiting on auth endpoints (5 req/min via Traefik)
- [x] Account lockout after failed attempts (via rate limiting)
- [x] Refresh token rotation on use (old token invalidated)

## Input Validation
- [x] All API endpoints validate input via Pydantic v2 schemas
- [x] File uploads: MIME type validation (JPEG/PNG only)
- [x] File uploads: size limit (10MB max)
- [x] SQL: parameterized queries via SQLAlchemy (no f-strings)
- [x] Path parameters validated as UUID where applicable
- [x] Query parameters validated with bounds (page >= 1, per_page <= 100)

## Data Protection
- [x] User photos processed in-memory only, never saved (ADR-003)
- [x] GDPR: data export endpoint (GET /auth/me/export)
- [x] GDPR: account deletion endpoint (DELETE /auth/me)
- [x] Password confirmation required for account deletion
- [x] Audit logging for sensitive operations (GDPR export/delete)
- [x] Database schema isolation between services

## Network Security
- [x] HTTPS with Let's Encrypt (TLS 1.2+ minimum)
- [x] Modern cipher suites only
- [x] HSTS with preload and includeSubdomains
- [x] Security headers: X-Frame-Options, X-Content-Type, CSP
- [x] CORS restricted to specific origins
- [x] Internal Docker network (services not exposed to host)
- [x] DB and Redis ports not exposed in production

## Secrets Management
- [x] No secrets in code (env vars via .env files)
- [x] .env files in .gitignore
- [x] .env.example with placeholder values
- [x] JWT_SECRET shared via environment
- [x] ANTHROPIC_API_KEY via environment only

## Rate Limiting
- [x] Global: 100 req/min (Traefik)
- [x] Auth: 5 req/min (Traefik)
- [x] AI: 10 req/hour (Traefik) + per-user app-level
- [x] Vision scan: 10/hour per user (Redis)
- [x] Coach generate: 3/day per user (Redis)

## Dependency Security
- [x] Bandit SAST scanning in CI
- [x] Ruff security rules enabled (S-prefixed rules)
- [x] Docker images: specific version tags (no :latest)
- [x] Docker: multi-stage builds, non-root user
- [x] Python packages pinned to minimum versions

## Secrets Rotation Procedure
1. Generate new JWT_SECRET: `openssl rand -base64 32`
2. Update .env on server
3. Restart all services: `docker compose restart auth workouts ai analytics`
4. All existing tokens immediately invalidated (users re-login)
5. Generate new ANTHROPIC_API_KEY from Anthropic console if compromised
6. Rotate DB password: update .env + PostgreSQL ALTER USER
