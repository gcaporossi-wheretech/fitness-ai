# Architettura di sistema — Overview

## Diagramma C4 Context

```
+------------------+        +------------------+
|    Utente        |        |  Apple/Google    |
|  (25-60 anni,    |        |  App Store       |
|   palestra)      |        +--------+---------+
+--------+---------+                 |
         |                           | distribuzione
         | usa                       |
         v                           v
+------------------+        +------------------+
|   FitnessAI      |        |   FitnessAI      |
|   Mobile App     |------->|   Backend        |
|   (Flutter)      | REST   |   (AWS EC2)      |
+------------------+ API    +--------+---------+
                                     |
                            +--------+---------+
                            |        |         |
                    +-------v-+  +---v------+  +---v-------+
                    |PostgreSQL|  |  Redis   |  |Claude API |
                    |Database  |  |Cache/MQ  |  |(Anthropic)|
                    +----------+  +----------+  +-----------+
```

## Diagramma C4 Container

```
                    +-----------------------------------------------------------+
                    |              AWS EC2 (Docker Compose)                      |
                    |                                                           |
  Mobile App       |  +-----------+                                            |
  (Flutter)  ----->|  | Traefik   |--- /auth/* ------> +----------+            |
                   |  | :80/:443  |                    | Auth     |            |
  Dashboard  ----->|  | API GW    |--- /workouts/* --> | :8001    |            |
  (browser)        |  |           |                    +----------+            |
                   |  |           |--- /ai/* --------> +----------+            |
                   |  |           |                    | Workouts |            |
                   |  |           |--- /analytics/* -> | :8002    |            |
                   |  |           |                    +----------+            |
                   |  |           |--- /* -----------> +----------+  +------+  |
                   |  +-----------+                    | AI       |->| Redis|  |
                   |                                   | :8003    |  | :6379|  |
                   |                    +----------+   +----------+  +------+  |
                   |                    | Next.js  |   +----------+            |
                   |                    | :3000    |   | Analytics|            |
                   |                    +----------+   | :8004    |  +------+  |
                   |                                   +----------+->|Postgr|  |
                   |                                                 |SQL   |  |
                   |                                                 |:5432 |  |
                   +-----------------------------------------------------------+
                                      |
                                      v
                              +---------------+
                              | Claude API    |
                              | (Anthropic)   |
                              +---------------+
```

## Container

| Container | Tecnologia | Porta | Responsabilita |
|-----------|-----------|-------|----------------|
| **traefik** | Traefik v3 | 80, 443 | API Gateway: routing path-based, HTTPS Let's Encrypt, rate limiting, security headers, auto-discovery Docker labels |
| **auth** | FastAPI (Python 3.12) | 8001 | Registrazione, login, JWT, WebAuthn, profilo, crediti AI |
| **workouts** | FastAPI (Python 3.12) | 8002 | CRUD schede/sessioni, sync offline, database esercizi |
| **ai** | FastAPI (Python 3.12) | 8003 | Vision scan, Coach generation, prompt engineering, caching Redis |
| **analytics** | FastAPI (Python 3.12) | 8004 | Progressione, volume, aderenza, report |
| **db** | PostgreSQL 16 | 5432 | Database condiviso con schema separati per servizio |
| **redis** | Redis 7 | 6379 | Cache AI (hash foto -> risultati) + message queue (Redis Streams per job AI asincroni) |
| **web** | Next.js 14 | 3000 | Dashboard utente |
| **app** | Flutter 3.32+ | — | Mobile app nativa (non in Docker, distribuita via store) |

## Comunicazione tra servizi

| Da | A | Pattern | Protocollo |
|----|---|---------|-----------|
| Flutter app | Traefik | Sincrono | HTTPS REST (JSON) |
| Dashboard web | Traefik | Sincrono | HTTPS REST (JSON) |
| Traefik | auth/workouts/ai/analytics | Sincrono | HTTP REST (Docker network interno) |
| ai service | Claude API | Sincrono | HTTPS REST |
| ai service | Redis | Sincrono + Async | Redis Streams per job asincroni, GET/SET per cache |
| Tutti i servizi | db | Sincrono | TCP (asyncpg) |

## Routing Traefik (path-based)

| Path prefix | Servizio destinazione | Rate limit |
|-------------|----------------------|------------|
| `/auth/*` | auth:8001 | 5/min (login/register), standard per il resto |
| `/workouts/*` | workouts:8002 | 100/min globale |
| `/ai/*` | ai:8003 | 10/ora (vision), 3/giorno (coach) |
| `/analytics/*` | analytics:8004 | 100/min globale |
| `/*` (fallback) | web:3000 | Standard |

## Database: schema separati

Ogni servizio ha il proprio schema PostgreSQL per isolamento logico:
- `auth.*` — users, refresh_tokens, webauthn_credentials
- `workouts.*` — workout_plans, workout_sessions, exercises
- `ai.*` — ai_vision_scans, ai_coach_generations
- `analytics.*` — viste materializzate e tabelle di aggregazione

Questo permette ownership chiara dei dati mantenendo un singolo database fisico per semplicita operativa.

## Perche microservizi (evoluzione da modular monolith)

Vedi [ADR-004: Microservices Architecture](../adr/004-microservices-architecture.md) per la decisione completa.

Motivazioni principali:
- Scalabilita indipendente: il servizio AI ha requisiti diversi (GPU future, burst)
- Deploy indipendente: fix di auth non richiede rebuild di AI
- Isolamento dei guasti: crash del servizio analytics non impatta auth
- Redis per job asincroni: i job AI lunghi richiedono una coda, non sync HTTP
