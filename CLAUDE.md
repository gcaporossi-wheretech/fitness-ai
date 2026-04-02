# FitnessAI — Coach AI personale per il fitness

## Progetto
App fitness commerciale con AI: riconoscimento macchinari da foto, schede personalizzate da analisi corporea, workout tracking completo. Target: 25-60 anni, palestre commerciali. Business model freemium con crediti AI.

## Architettura: Modular Monolith ibrido

| Container | Tecnologia | Responsabilita |
|-----------|-----------|----------------|
| `nginx` | Nginx | Reverse proxy, HTTPS, rate limiting |
| `api` | FastAPI (Python 3.12) | Backend monolitico con 4 moduli |
| `web` | Next.js 14 | Dashboard utente |
| `db` | PostgreSQL 16 | Persistenza, JSONB per dati flessibili |
| `app` | Flutter 3.32+ | Mobile nativa (iOS + Android) — non in Docker |

### Moduli backend (`api/modules/`)
- **auth**: registrazione, login, JWT, WebAuthn
- **workouts**: CRUD schede/sessioni/esercizi, sync offline
- **ai**: proxy Claude API, prompt engineering, caching
- **analytics**: statistiche, progressione, grafici

## Stack e convenzioni
- **Python**: 3.12+, async, type hints obbligatori, Pydantic v2 per modelli
- **Flutter**: Dart 3.8+, Riverpod 3.x, Hive, freezed, clean architecture
- **Next.js**: App Router, TypeScript strict, Tailwind + shadcn/ui
- **Database**: Alembic per migrazioni, JSONB per dati flessibili
- **Naming**: snake_case (Python), camelCase (Dart/TS), kebab-case (file/route)

## Strumenti progetto
- **Repository**: https://github.com/gcaporossi-wheretech/fitness-ai
- **Issues/Board**: GitHub Issues + GitHub Projects
- **Docs**: `docs/` in questo repo
- **Prototipo**: https://github.com/gcaporossi-wheretech/gym-tracker-app
- **CI/CD**: GitHub Actions

## Workflow
- Branch: `main` (produzione) <- `develop` <- `feature/NNN-descrizione`
- Commit: `#NNN tipo: descrizione` (feat, fix, refactor, test, docs, ci)
- PR: sempre verso develop, con checklist review
- Ogni PR deve passare la pipeline verde

## Cosa NON fare
1. NON usare Kubernetes — Docker Compose su EC2
2. NON creare microservizi separati — moduli interni a FastAPI
3. NON usare ORM pesanti — SQLAlchemy Core o query dirette con asyncpg
4. NON hardcodare secrets — sempre env vars / .env (mai committato)
5. NON bypassare i test — ogni modulo ha i propri test obbligatori

## Context Recovery (inizio sessione)
1. Leggi questo file e `.claude/` per regole e skill
2. Controlla GitHub Issues: task In Progress o ultimo completato
3. Leggi `docs/` per architettura e specifiche aggiornate
4. `git log --oneline -10` per ultimi commit
5. Riprendi il task in corso o identifica il prossimo

## Compaction Instructions
Preserva: architettura (4 container + 4 moduli), task corrente (numero issue + stato), decisioni recenti, file modificati nella sessione, prossimi passi.
