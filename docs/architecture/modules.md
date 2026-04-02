# Specifiche per modulo backend

## Struttura standard di ogni modulo

```
api/modules/<nome>/
  __init__.py       # Module docstring e export
  router.py         # FastAPI APIRouter con prefix /<nome>
  schemas.py        # Pydantic v2 request/response models
  models.py         # SQLAlchemy models / DB queries
  service.py        # Business logic
  dependencies.py   # FastAPI dependencies (auth, rate limit)
```

---

## Modulo: auth

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

### Modello dati

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100),
    age INTEGER,
    goals JSONB,
    limitations JSONB,
    ai_credits INTEGER DEFAULT 10,
    language VARCHAR(5) DEFAULT 'it',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE webauthn_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    credential_id BYTEA UNIQUE NOT NULL,
    public_key BYTEA NOT NULL,
    sign_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Sicurezza
- Password: bcrypt cost 12
- JWT: HS256 con secret da env var, expiry 15min
- Refresh token: opaque UUID, hash in DB, expiry 7gg
- Rate limit: 5 tentativi login falliti -> lockout 15min
- WebAuthn: challenge con timeout 60s

---

## Modulo: workouts

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

### Modello dati

```sql
CREATE TABLE workout_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    phases JSONB,
    days JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    source VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    plan_id UUID REFERENCES workout_plans(id),
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

CREATE TABLE exercises (
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

CREATE UNIQUE INDEX idx_sessions_client_id ON workout_sessions(client_id);
```

### Sync offline
- Client invia batch di sessioni con client_id unico
- Server fa UPSERT: se client_id esiste, aggiorna solo se updated_at piu recente
- Conflitto: last-write-wins basato su timestamp
- Response: lista di sessioni sincronizzate con stato (created/updated/conflict)

---

## Modulo: ai

### Responsabilita
- Riconoscimento macchinario da foto (AI Vision)
- Generazione scheda personalizzata da foto corporee (AI Coach)
- Caching risultati per ridurre costi API
- Gestione crediti: decrementa saldo utente ad ogni chiamata AI
- Prompt engineering e template management

### API Endpoints

| Method | Path | Descrizione | Auth | Crediti |
|--------|------|-------------|------|---------|
| POST | /ai/vision/scan | Foto macchinario -> esercizi | JWT | 1 |
| POST | /ai/coach/generate | Foto corpo + dati -> scheda | JWT | 5 |
| GET | /ai/vision/history | Storico scan | JWT | 0 |
| GET | /ai/coach/history | Storico schede generate | JWT | 0 |

### Modello dati

```sql
CREATE TABLE ai_vision_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    image_hash VARCHAR(64),
    equipment_name VARCHAR(255),
    equipment_brand VARCHAR(100),
    exercises JSONB,
    raw_response JSONB,
    credits_used INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE ai_coach_generations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    input_data JSONB,
    photo_count INTEGER,
    generated_plan_id UUID REFERENCES workout_plans(id),
    raw_response JSONB,
    credits_used INTEGER DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Sicurezza
- Foto utente: processate in memoria, MAI salvate su disco/S3
- Rate limit: max 10 scan/ora, max 3 coach/giorno
- Caching: stessa foto (hash) restituisce risultato cached senza consumare crediti
- Input validation: solo JPEG/PNG, max 10MB per foto
- Claude API key: env var, mai nel codice

### Prompt engineering
- Template prompt versionati in api/modules/ai/prompts/
- Ogni template ha: versione, test case, expected output format
- Prompt per Vision: structured JSON output con equipment name, brand, exercises list
- Prompt per Coach: analisi foto + dati utente -> scheda strutturata JSON

---

## Modulo: analytics

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

### Note
- Calcoli basati su dati in workout_sessions (JSONB exercises)
- Query aggregate con window functions PostgreSQL
- Caching risultati in-memory per MVP
