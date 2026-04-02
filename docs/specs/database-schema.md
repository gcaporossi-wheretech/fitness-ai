# Database Schema — FitnessAI

## Overview
PostgreSQL 16 con estensione pgcrypto (gen_random_uuid). JSONB per dati flessibili (esercizi nelle sessioni, obiettivi utente, fasi della scheda).

**Schema separation**: ogni microservizio ha il proprio schema PostgreSQL per isolamento logico dei dati. Un singolo database fisico per semplicita operativa.
- `auth.*` — utenti, token, credenziali WebAuthn
- `workouts.*` — piani, sessioni, esercizi
- `ai.*` — scan vision, generazioni coach
- `analytics.*` — viste materializzate (futuro)

## ER Diagram (testuale)

```
users 1---N workout_plans
users 1---N workout_sessions
users 1---N webauthn_credentials
users 1---N refresh_tokens
users 1---N ai_vision_scans
users 1---N ai_coach_generations

workout_plans 1---N workout_sessions
workout_plans 1---1 ai_coach_generations (generated_plan_id)

exercises (standalone reference table)
```

## Tables

### users
Primary entity. Owns all other data via user_id FK.
- id: UUID PK
- email: VARCHAR(255) UNIQUE NOT NULL
- password_hash: VARCHAR(255) NOT NULL
- name: VARCHAR(100)
- age: INTEGER
- goals: JSONB (e.g., {"primary": "muscle_gain", "secondary": "fat_loss"})
- limitations: JSONB (e.g., {"shoulder": "avoid overhead press"})
- ai_credits: INTEGER DEFAULT 10
- language: VARCHAR(5) DEFAULT 'it'
- is_active: BOOLEAN DEFAULT true
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ

### workout_plans
Schede di allenamento. Source indica se creata manualmente, da AI, o importata.
- id: UUID PK
- user_id: UUID FK -> users (CASCADE)
- name: VARCHAR(255) NOT NULL
- description: TEXT
- phases: JSONB (array of phase objects)
- days: JSONB NOT NULL (array of day objects with exercises)
- is_active: BOOLEAN DEFAULT true
- source: VARCHAR(50) ('manual', 'ai_coach', 'imported')
- created_at, updated_at: TIMESTAMPTZ

### workout_sessions
Sessioni completate. exercises in JSONB per flessibilita.
- id: UUID PK
- user_id: UUID FK -> users (CASCADE)
- plan_id: UUID FK -> workout_plans (nullable, sessione libera)
- day_name: VARCHAR(100)
- started_at: TIMESTAMPTZ NOT NULL
- completed_at: TIMESTAMPTZ
- duration_seconds: INTEGER
- exercises: JSONB NOT NULL (array of exercise logs with sets)
- notes: TEXT
- synced_at: TIMESTAMPTZ (null = not yet synced from mobile)
- client_id: UUID NOT NULL UNIQUE (dedup key from mobile)
- created_at: TIMESTAMPTZ

### exercises
Reference table con esercizi predefiniti e custom.
- id: UUID PK
- name: VARCHAR(255) NOT NULL
- name_en: VARCHAR(255)
- muscle_groups: JSONB (array of strings)
- equipment: VARCHAR(100)
- exercise_type: VARCHAR(20) ('weighted', 'timed', 'bodyweight')
- description: TEXT
- description_en: TEXT
- is_custom: BOOLEAN DEFAULT false
- user_id: UUID FK -> users (nullable, solo per custom)
- created_at: TIMESTAMPTZ

### ai_vision_scans, ai_coach_generations
Vedi docs/architecture/modules.md (modulo ai)

### webauthn_credentials, refresh_tokens
Vedi docs/architecture/modules.md (modulo auth)

## Indexes
- users: email (unique)
- workout_sessions: (user_id, started_at), client_id (unique)
- workout_plans: (user_id, is_active)
- exercises: (muscle_groups) GIN, (equipment)
- ai_vision_scans: (user_id, image_hash)

## Migration strategy
- Alembic per tutte le migrazioni
- Ogni migrazione reversibile (upgrade + downgrade)
- Naming: `NNNN_description.py` (auto-increment)
- Non modificare mai una migrazione gia applicata — creare una nuova
