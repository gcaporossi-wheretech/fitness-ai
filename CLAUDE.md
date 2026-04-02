# FitnessAI — Coach AI personale per il fitness

## Progetto
App fitness commerciale con AI: riconoscimento macchinari da foto, schede personalizzate da analisi corporea, workout tracking completo. Target: 25-60 anni, palestre commerciali. Business model freemium con crediti AI.

## Architettura: Microservizi con Docker Compose

| Container | Tecnologia | Porta | Responsabilita |
|-----------|-----------|-------|----------------|
| `traefik` | Traefik v3 | 80, 443 | API Gateway — routing path-based, HTTPS, rate limiting |
| `auth` | FastAPI | 8001 | Registrazione, login, JWT, WebAuthn, profilo, crediti |
| `workouts` | FastAPI | 8002 | CRUD schede/sessioni, sync offline, esercizi |
| `ai` | FastAPI | 8003 | Vision scan, Coach generation, caching Redis |
| `analytics` | FastAPI | 8004 | Progressione, volume, aderenza, report |
| `db` | PostgreSQL 16 | 5432 | Database condiviso (schema separati per servizio) |
| `redis` | Redis 7 | 6379 | Cache AI + message queue (Redis Streams) |
| `web` | Next.js 14 | 3000 | Dashboard utente |
| `app` | Flutter 3.32+ | — | Mobile nativa (iOS + Android) — non in Docker |

### Comunicazione
- Client -> Traefik -> servizi (HTTP sincrono, path-based routing)
- AI jobs: asincroni via Redis Streams (client riceve job_id, polls per risultato)
- Servizi validano JWT autonomamente (shared secret)
- Database: schema separati, analytics ha read-only cross-schema

## Stack e convenzioni
- **Python**: 3.12+, async, type hints obbligatori, Pydantic v2
- **Ogni servizio**: `services/<nome>/` con app/, tests/, Dockerfile, requirements.txt
- **Flutter**: Dart 3.8+, Riverpod 3.x, Hive, freezed, clean architecture
- **Next.js**: App Router, TypeScript strict, Tailwind + shadcn/ui
- **Database**: Alembic migrazioni, schema separati per servizio
- **Naming**: snake_case (Python), camelCase (Dart/TS), kebab-case (file/route)

## Strumenti progetto
- **Repository**: https://github.com/gcaporossi-wheretech/fitness-ai
- **Issues/Board**: GitHub Issues + GitHub Projects
- **Docs**: `docs/` in questo repo
- **Prototipo**: https://github.com/gcaporossi-wheretech/gym-tracker-app
- **CI/CD**: GitHub Actions (matrix build per servizio)

## Workflow
- Branch: `main` (produzione) <- `develop` <- `feature/NNN-descrizione`
- Commit: `#NNN tipo: descrizione` (feat, fix, refactor, test, docs, ci)
- PR: sempre verso develop, con checklist review
- Ogni PR deve passare la pipeline verde

## Cosa NON fare
1. NON usare Kubernetes — Docker Compose su EC2
2. NON creare FK fisiche tra schema di servizi diversi — usare user_id da JWT
3. NON usare ORM pesanti — SQLAlchemy Core o query dirette con asyncpg
4. NON hardcodare secrets — sempre env vars / .env (mai committato)
5. NON bypassare i test — ogni servizio ha i propri test obbligatori

## Context Recovery (inizio sessione)
1. Leggi questo file e `.claude/` per regole e skill
2. Controlla GitHub Issues: task In Progress o ultimo completato
3. Leggi `docs/` per architettura e specifiche aggiornate
4. `git log --oneline -10` per ultimi commit
5. Riprendi il task in corso o identifica il prossimo

## Compaction Instructions
Preserva: architettura (7 container + 4 servizi), task corrente (numero issue + stato), decisioni recenti, file modificati nella sessione, prossimi passi.
