# Security Architecture

## Modello autenticazione

### Flusso principale
1. Utente si registra con email + password
2. Login restituisce access token JWT (15min) + refresh token (7gg)
3. Ogni richiesta API include JWT in header `Authorization: Bearer <token>`
4. Token scaduto: client usa refresh token per ottenerne uno nuovo
5. WebAuthn/Face ID: registra dispositivo dopo primo login, poi login biometrico

### JWT Structure
- Algorithm: HS256
- Payload: `{sub: user_id, exp: timestamp, iat: timestamp}`
- Secret: env var `JWT_SECRET` (min 32 chars, random)
- NO dati sensibili nel payload (no email, no nome)

### Refresh token
- UUID v4 opaco, hashato con SHA256 prima di salvare in DB
- Un utente puo avere max 5 refresh token attivi (multi-device)
- Revoca: eliminazione da DB (logout, cambio password)

## Autorizzazione
- RBAC semplice: `user` (default) e `admin` (futuro)
- Ogni endpoint protetto verifica che `user_id` nel JWT corrisponda ai dati richiesti
- No accesso cross-utente: utente A non puo vedere dati di utente B

## Gestione secrets

| Secret | Dove | Rotazione |
|--------|------|-----------|
| JWT_SECRET | env var (.env) | Alla prima compromissione |
| DATABASE_URL | env var (.env) | Al cambio infrastruttura |
| ANTHROPIC_API_KEY | env var (.env) | Ogni 90 giorni consigliato |
| WEBAUTHN_RP_ID | env var (.env) | Mai (legato al dominio) |

- `.env` in `.gitignore` — mai committato
- `.env.example` con placeholder committato
- In produzione: env vars iniettate nel container Docker

## Network security

```
Internet -> Nginx (:443 HTTPS) -> api (:8000 HTTP interno)
                                -> web (:3000 HTTP interno)
         -> Nginx (:80) -> redirect a :443

db (:5432) -> accessibile SOLO da api (Docker network interno)
```

- TLS 1.2+ con Let's Encrypt (certbot auto-renewal)
- Comunicazione tra container: rete Docker interna (non esposta)
- PostgreSQL: bind su Docker network, no bind su 0.0.0.0
- Nginx security headers: HSTS, X-Frame-Options DENY, CSP, X-Content-Type-Options nosniff

## Data protection

### Dati a riposo
- PostgreSQL: encryption at rest tramite filesystem encryption (EBS encrypted su AWS)
- Password utente: bcrypt hash (cost 12), mai in chiaro
- Refresh token: SHA256 hash in DB

### Dati in transito
- HTTPS (TLS 1.2+) per tutto il traffico esterno
- Docker internal network per traffico tra container (trusted network)

### Foto utente
- **CRITICO**: le foto corporee sono dati sensibili
- Processate in memoria RAM (buffer), inviate a Claude API, poi scartate
- MAI salvate su disco, S3, o database
- Solo il risultato (testo) viene salvato
- Hash SHA256 della foto salvato per caching/dedup (no ricostruzione possibile)

### GDPR compliance
- Export dati: endpoint `GET /auth/me/export` restituisce tutti i dati utente in JSON
- Cancellazione: endpoint `DELETE /auth/me` elimina account e tutti i dati (CASCADE)
- Consenso: registrazione richiede accettazione termini e privacy policy

## Rate limiting (Nginx + applicativo)

| Endpoint | Limite | Motivazione |
|----------|--------|-------------|
| POST /auth/login | 5/min per IP | Brute force prevention |
| POST /auth/register | 3/min per IP | Spam prevention |
| POST /ai/vision/scan | 10/ora per utente | Costo API |
| POST /ai/coach/generate | 3/giorno per utente | Costo API alto |
| GET /* | 100/min per utente | Fair usage |

## Audit logging
- Login (successo/fallimento) con IP e user-agent
- Cambio password
- Export dati
- Cancellazione account
- Chiamate AI (crediti consumati)
- Log in formato JSON strutturato, retention 90 giorni
