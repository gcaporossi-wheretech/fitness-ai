# Specifiche per microservizio

## Struttura standard di ogni servizio

```
services/<nome>/
  app/
    __init__.py       # Service docstring
    main.py           # FastAPI app entry point
    config.py         # Pydantic Settings from env vars
    router.py         # FastAPI APIRouter
    schemas.py        # Pydantic v2 request/response models
    models.py         # SQLAlchemy ORM models (service-owned schema)
    service.py        # Business logic
    dependencies.py   # FastAPI dependencies (auth, rate limit)
    database.py       # DB engine and session factory
    security.py       # JWT decode (shared secret validation)
  tests/
    __init__.py
    conftest.py       # Test fixtures
    test_router.py    # Integration tests
    test_service.py   # Unit tests
  Dockerfile          # Multi-stage build, non-root user
  requirements.txt    # Production dependencies
  requirements-dev.txt # Test/lint dependencies
  pyproject.toml      # Ruff, pytest, coverage config
  .env.example        # Environment variable template
  README.md           # Service docs
```

---

## Servizio: auth (porta 8001)

### Responsabilita
- Registrazione utente (email + password)
- Login e gestione JWT (access token 15min + refresh token 7gg)
- WebAuthn/Face ID registration e authentication
- Profilo utente (nome, eta, obiettivi, limitazioni fisiche)
- Gestione crediti AI (saldo, consumo, ricarica)

### API Endpoints

| Method | Path | Descrizione | Auth |
|--------|------|-------------|------|
| POST | /auth/register | Registrazione | No |
| POST | /auth/login | Login email+password | No |
| POST | /auth/refresh | Refresh token | Refresh token |
| POST | /auth/webauthn/register | Registra dispositivo WebAuthn | JWT |
| POST | /auth/webauthn/login | Login WebAuthn | No |
| GET | /auth/me | Profilo utente corrente | JWT |
| PATCH | /auth/me | Aggiorna profilo | JWT |
| GET | /auth/credits | Saldo crediti AI | JWT |
| GET | /health | Health check | No |

### Database schema: `auth`

```sql
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100),
    age INTEGER,
    goals JSONB,
    limitations JSONB,
    ai_credits INTEGER DEFAULT 10,
    language VARCHAR(5) DEFAULT 'it',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE auth.webauthn_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    credential_id BYTEA UNIQUE NOT NULL,
    public_key BYTEA NOT NULL,
    sign_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE auth.refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Sicurezza
- Password: bcrypt cost 12
- JWT: HS256 con secret da env var, expiry 15min
- Refresh token: opaque UUID, hash in DB, expiry 7gg
- Rate limit: 5 tentativi login falliti -> lockout 15min (via Traefik middleware)
- WebAuthn: challenge con timeout 60s

---

## Servizio: workouts (porta 8002)

### Responsabilita
- CRUD schede di allenamento (workout plan)
- Gestione sessioni di allenamento (workout session)
- Tracking set/rep/peso per esercizio
- Sync offline: riceve batch di sessioni dal mobile, gestisce conflitti
- Database esercizi (nome, muscoli, tipo, equipment)

### API Endpoints

| Method | Path | Descrizione | Auth |
|--------|------|-------------|------|
| GET | /workouts/plans | Lista schede utente | JWT |
| POST | /workouts/plans | Crea nuova scheda | JWT |
| GET | /workouts/plans/{id} | Dettaglio scheda | JWT |
| PATCH | /workouts/plans/{id} | Modifica scheda | JWT |
| DELETE | /workouts/plans/{id} | Elimina scheda | JWT |
| GET | /workouts/sessions | Lista sessioni (paginata) | JWT |
| POST | /workouts/sessions | Salva sessione completata | JWT |
| POST | /workouts/sync | Sync batch offline sessions | JWT |
| GET | /workouts/exercises | Database esercizi | JWT |
| GET | /health | Health check | No |

### Database schema: `workouts`

```sql
CREATE SCHEMA IF NOT EXISTS workouts;

CREATE TABLE workouts.workout_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,  -- FK logica a auth.users (validata via JWT)
    name VARCHAR(255) NOT NULL,
    description TEXT,
    phases JSONB,
    days JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    source VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE workouts.workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    plan_id UUID REFERENCES workouts.workout_plans(id),
    day_name VARCHAR(100),
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    exercises JSONB NOT NULL,
    notes TEXT,
    synced_at TIMESTAMPTZ,
    client_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE workouts.exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    name_en VARCHAR(255),
    muscle_groups JSONB,
    equipment VARCHAR(100),
    exercise_type VARCHAR(20),
    description TEXT,
    description_en TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_sessions_client_id ON workouts.workout_sessions(client_id);
```

### Sync offline
- Client invia batch di sessioni con client_id unico
- Server fa UPSERT: se client_id esiste, aggiorna solo se updated_at piu recente
- Conflitto: last-write-wins basato su timestamp
- Response: lista di sessioni sincronizzate con stato (created/updated/conflict)

### Note su cross-service
- `user_id` e un UUID validato dal JWT, non una FK fisica a auth.users
- Il servizio workouts valida il JWT autonomamente (shared secret)

---

## Servizio: ai (porta 8003)

### Responsabilita
- Riconoscimento macchinario da foto (AI Vision)
- Generazione scheda personalizzata da foto corporee (AI Coach)
- Caching risultati via Redis (hash SHA256 della foto -> risultato)
- Job asincroni via Redis Streams per operazioni lunghe
- Gestione crediti: decrementa saldo utente ad ogni chiamata AI
- Prompt engineering e template management

### API Endpoints

| Method | Path | Descrizione | Auth | Crediti |
|--------|------|-------------|------|---------|
| POST | /ai/vision/scan | Foto macchinario -> esercizi | JWT | 1 |
| POST | /ai/coach/generate | Foto corpo + dati -> scheda | JWT | 5 |
| GET | /ai/vision/history | Storico scan | JWT | 0 |
| GET | /ai/coach/history | Storico schede generate | JWT | 0 |
| GET | /ai/jobs/{job_id} | Stato job asincrono | JWT | 0 |
| GET | /health | Health check | No | 0 |

### Database schema: `ai`

```sql
CREATE SCHEMA IF NOT EXISTS ai;

CREATE TABLE ai.ai_vision_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    image_hash VARCHAR(64),
    equipment_name VARCHAR(255),
    equipment_brand VARCHAR(100),
    exercises JSONB,
    raw_response JSONB,
    credits_used INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai.ai_coach_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    input_data JSONB,
    photo_count INTEGER,
    generated_plan JSONB,
    raw_response JSONB,
    credits_used INTEGER DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Redis usage
- **Cache**: key = `ai:vision:{image_hash}`, value = JSON result, TTL = 7d
- **Streams**: stream = `ai:jobs`, consumer group per processing
- **Job flow**: POST /ai/vision/scan -> publish to stream -> return job_id -> client polls GET /ai/jobs/{job_id}

### Sicurezza
- Foto utente: processate in memoria, MAI salvate su disco/S3
- Rate limit: max 10 scan/ora, max 3 coach/giorno (via Traefik + applicativo)
- Caching: stessa foto (hash) restituisce risultato cached senza consumare crediti
- Input validation: solo JPEG/PNG, max 10MB per foto
- Claude API key: env var, mai nel codice

### Prompt engineering
- Template prompt versionati in services/ai/app/prompts/
- Ogni template ha: versione, test case, expected output format
- Prompt per Vision: structured JSON output con equipment name, brand, exercises list
- Prompt per Coach: analisi foto + dati utente -> scheda strutturata JSON

---

## Servizio: analytics (porta 8004)

### Responsabilita
- Calcolo statistiche aggregate (volume, frequenza, aderenza)
- Progressione carichi per esercizio
- Report settimanali/mensili

### API Endpoints

| Method | Path | Descrizione | Auth |
|--------|------|-------------|------|
| GET | /analytics/progress/{exercise_id} | Progressione peso per esercizio | JWT |
| GET | /analytics/volume | Volume per gruppo muscolare (periodo) | JWT |
| GET | /analytics/adherence | Aderenza al piano (periodo) | JWT |
| GET | /analytics/summary | Riepilogo generale | JWT |
| GET | /health | Health check | No |

### Note
- Legge dati da schema `workouts` (read-only cross-schema access)
- Calcoli basati su workout_sessions.exercises (JSONB)
- Query aggregate con window functions PostgreSQL
- Caching risultati in-memory per MVP

### Cross-service data access
Il servizio analytics ha accesso read-only allo schema `workouts` del database condiviso. Questo e un compromesso pragmatico per evitare la complessita di sincronizzazione dati tra servizi per un singolo sviluppatore. Se il team cresce, questo accesso verra sostituito da un'API dedicata o da eventi.
