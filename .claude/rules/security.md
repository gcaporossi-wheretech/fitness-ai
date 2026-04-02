# Security Rules
Applies to: **/*.{py,dart,ts,tsx,yaml,yml}

## Secrets
- NEVER commit secrets, API keys, passwords, or tokens
- Use .env files (listed in .gitignore) for local development
- Use environment variables in Docker/production
- .env.example with placeholder values MUST exist for every service
- JWT_SECRET shared across all services — single source of truth in root .env

## Authentication
- JWT with short expiration (15 min access, 7 day refresh)
- Each service validates JWT independently (shared secret, no inter-service call)
- WebAuthn/Face ID as primary auth for mobile
- Password hashing: bcrypt with cost factor >= 12
- Account lockout after 5 failed login attempts

## Input validation
- Every API endpoint validates input via Pydantic schema
- Every Flutter form validates client-side AND server revalidates
- File uploads: validate MIME type, size limit (max 10MB photos)
- SQL: parameterized queries only — never string interpolation

## Communication
- HTTPS everywhere via Traefik (Let's Encrypt ACME)
- API rate limiting: Traefik middleware (global + per-endpoint for AI)
- CORS configured for specific origins only (via Traefik dynamic.yml)
- Internal Docker network — no service ports exposed to host except Traefik

## Data protection
- User photos processed and deleted — never stored long-term
- GDPR: export and delete user data on request
- Audit log for sensitive operations (login, data export, account delete)
- Database schema isolation: each service owns its data

## Cross-service security
- No physical FK between schemas — prevents cascade vulnerabilities
- user_id always from JWT, never from request body for authorization
- Redis connections only from AI service — not exposed to others
