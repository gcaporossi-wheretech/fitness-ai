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
                            |                  |
                    +-------v------+   +-------v------+
                    | PostgreSQL   |   | Claude API   |
                    | Database     |   | (Anthropic)  |
                    +--------------+   +--------------+
```

## Diagramma C4 Container

```
                    +------------------------------------------+
                    |           AWS EC2 (Docker Compose)        |
                    |                                          |
  Mobile App       |  +--------+    +---------+               |
  (Flutter)  ----->|  | Nginx  |--->| FastAPI |               |
                   |  | :443   |    | :8000   |               |
  Dashboard  ----->|  |        |--->+---------+               |
  (browser)        |  |        |    | modules:|               |
                   |  |        |    | - auth  |               |
                   |  +--------+    | - work  |   +--------+  |
                   |    |           | - ai    |-->| Postgre|  |
                   |    |           | - analy |   | SQL    |  |
                   |    |           +---------+   | :5432  |  |
                   |    |                         +--------+  |
                   |    +---------->+---------+               |
                   |                | Next.js |               |
                   |                | :3000   |               |
                   |                +---------+               |
                   +------------------------------------------+
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
| **nginx** | Nginx 1.25 | 80, 443 | Reverse proxy, TLS termination, rate limiting, security headers, static files |
| **api** | FastAPI (Python 3.12) | 8000 | Backend API monolitico modulare — tutta la business logic |
| **web** | Next.js 14 | 3000 | Dashboard utente — visualizzazione dati, grafici, profilo |
| **db** | PostgreSQL 16 | 5432 | Database relazionale con JSONB per dati flessibili |
| **app** | Flutter 3.32+ | — | Mobile app nativa (non in Docker, distribuita via store) |

## Moduli backend (api/modules/)

| Modulo | Responsabilita | Dipendenze interne | Dipendenze esterne |
|--------|---------------|--------------------|--------------------|
| **auth** | Registrazione, login, JWT, WebAuthn, profilo utente | — | bcrypt, PyJWT |
| **workouts** | CRUD schede, sessioni, esercizi, sync offline | auth (user_id) | — |
| **ai** | Riconoscimento macchinari, generazione schede, caching | auth (user_id, credits), workouts (exercise data) | Claude API |
| **analytics** | Statistiche, progressione carichi, aderenza | auth (user_id), workouts (session data) | — |

## Comunicazione

| Da | A | Pattern | Protocollo |
|----|---|---------|-----------|
| Flutter app | api | Sincrono | HTTPS REST (JSON) |
| Dashboard web | api | Sincrono | HTTPS REST (JSON) |
| api (ai module) | Claude API | Sincrono | HTTPS REST |
| api (tutti) | db | Sincrono | TCP (asyncpg) |
| Moduli interni | Moduli interni | Chiamata diretta | Import Python (no HTTP) |

## Decisione: perche NON microservizi

Per sviluppatore singolo su EC2 con Docker Compose:
- Overhead operativo sproporzionato (N pipeline, N Dockerfile, service discovery)
- Debugging distribuito complesso senza team
- Docker Compose non supporta service mesh / sidecar pattern
- I moduli interni hanno gli stessi confini logici dei microservizi ma senza overhead di rete
- Estrazione futura possibile: ogni modulo ha interface chiare
