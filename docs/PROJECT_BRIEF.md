# FitnessAI — Project Brief

## Obiettivo
Sviluppare un'app fitness commerciale con AI che permette di riconoscere macchinari da foto, generare schede personalizzate analizzando foto corporee, e tracciare gli allenamenti. Target: utenti 25-60 anni in palestre commerciali, con business model freemium a crediti AI.

## Tagline
"Il tuo coach AI personale. Inquadra un macchinario, ottieni la scheda perfetta."

## Stakeholder
- **Fondatore/sviluppatore**: singolo sviluppatore, utente quotidiano del prototipo, validazione diretta in palestra
- **Utenti target**: 25-60 anni, livello intermedio, 3-6 allenamenti/settimana, palestra commerciale

## Ambito

### In scope (MVP)
- AI Vision: riconoscimento macchinari da foto (Claude Vision API)
- AI Coach: scheda personalizzata da foto corporee + dati utente
- Workout tracker: set tracker inline, timer recupero, cronometro
- Calendario dinamico con flessibilita
- Storico e grafici (progressione carichi, volume, aderenza)
- Auth: email/password + WebAuthn/Face ID
- Offline-first con sync
- Multilingua: IT + EN
- Dashboard web per visualizzazione dati
- Deploy: AWS EC2 + Docker Compose
- Pubblicazione: App Store + Play Store

### Out of scope (v2+)
- AI Form Check (analisi video)
- AI Progression avanzata
- Social features
- Personal trainer dashboard
- Integrazione wearable
- Lingue oltre IT/EN

## Architettura
**Modular Monolith ibrido**: backend FastAPI monolitico con 4 moduli interni (auth, workouts, ai, analytics), orchestrato con Docker Compose (4 container: nginx, api, web, db). Flutter app distribuita via store.

Motivazione: overhead microservizi sproporzionato per sviluppatore singolo su EC2 con Docker Compose. I confini modulari permettono estrazione futura in microservizi quando la scala lo richiede.

## Stack tecnologico

| Layer | Tecnologia |
|-------|-----------|
| Mobile | Flutter 3.32+, Riverpod 3.x, Hive, freezed |
| Backend | FastAPI, Python 3.12+, Pydantic v2, asyncpg |
| Dashboard | Next.js 14, TypeScript, Tailwind, shadcn/ui |
| Database | PostgreSQL 16 (JSONB), Alembic migrazioni |
| AI | Claude API (Anthropic) — Vision + Text |
| Infra | Docker Compose, Nginx, Let's Encrypt, AWS EC2 |
| CI/CD | GitHub Actions |

## Business model
Freemium con crediti AI:
- **Free**: workout tracker completo, 1 scheda, 3 scan macchinario/mese
- **Premium** (~9.99/mese): AI Vision illimitato, AI Coach, dashboard, export avanzato

## Rischi principali

| Rischio | Impatto | Mitigazione |
|---------|---------|-------------|
| Qualita riconoscimento macchinari | ALTO | POC precoce con 48 foto Technogym reali |
| Costi API Claude | MEDIO | Caching aggressivo, rate limiting, crediti |
| Complessita offline-sync | MEDIO | Last-write-wins con timestamp |
| Scope creep AI | ALTO | MVP limitato a Vision + Coach |

## Prototipo di riferimento
- Repo: https://github.com/gcaporossi-wheretech/gym-tracker-app
- Versione: 1.2.46 (62 file Dart, ~8000 righe, 41 test)
- Asset riusabili: design system, modelli dati, widget premium, timer, export

## Stima
4-5 mesi per sviluppatore singolo fino a MVP completo.
