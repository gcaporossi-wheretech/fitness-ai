# ADR-004: Migrazione a Microservizi con Traefik e Redis

## Stato
Accettata

## Contesto
Il progetto FitnessAI era stato inizialmente implementato come Modular Monolith (ADR-001). Dopo aver definito i confini dei moduli e validato il servizio auth, si e deciso di evolvere verso un'architettura a microservizi per i seguenti motivi:

1. **Scalabilita granulare**: il servizio AI ha requisiti di risorse diversi (burst di chiamate Claude API, potenziale uso GPU futuro) rispetto a auth o analytics
2. **Deploy indipendente**: un fix di sicurezza su auth non deve richiedere il rebuild del servizio AI
3. **Isolamento dei guasti**: un crash nel servizio analytics non deve impattare l'autenticazione
4. **Job asincroni**: le operazioni AI richiedono una coda (Redis Streams), non richieste sincrone
5. **Preparazione alla crescita**: se il team cresce, ogni sviluppatore puo lavorare su un servizio

## Decisione
Migrare a 7 container Docker Compose:

| Container | Tecnologia | Porta | Ruolo |
|-----------|-----------|-------|-------|
| traefik | Traefik v3 | 80, 443 | API Gateway — routing, HTTPS, rate limiting |
| auth | FastAPI | 8001 | Autenticazione, profilo, crediti |
| workouts | FastAPI | 8002 | Workout plans, sessions, exercises, sync |
| ai | FastAPI | 8003 | Vision, Coach, prompt engineering, caching |
| analytics | FastAPI | 8004 | Statistiche, progressione, aderenza |
| db | PostgreSQL 16 | 5432 | Database condiviso (schema separati) |
| redis | Redis 7 | 6379 | Cache AI + message queue (Streams) |

### Comunicazione
- Client -> Traefik -> servizi (HTTP sincrono, routing path-based)
- Servizi tra loro: nessuna comunicazione diretta nella prima versione
- AI jobs: asincroni via Redis Streams
- Database: schema separati per servizio, cross-schema read-only per analytics

### Compromessi pragmatici per sviluppatore singolo
- **Database condiviso**: un singolo PostgreSQL con schema separati anziche un DB per servizio. Riduce overhead operativo mantenendo isolamento logico.
- **Shared JWT secret**: tutti i servizi validano JWT con lo stesso secret anziche chiamare un servizio auth centrale. Piu semplice, meno overhead di rete.
- **Cross-schema read**: analytics legge direttamente lo schema workouts anziche ricevere eventi. Piu semplice, verra sostituito se il team cresce.

## Conseguenze
- PRO: scalabilita indipendente per servizio (specialmente AI)
- PRO: deploy indipendente — fix rapidi senza impatto su altri servizi
- PRO: isolamento dei guasti — crash contenuto al singolo servizio
- PRO: Redis Streams per job AI asincroni — migliore UX
- PRO: Traefik auto-discovery via Docker labels — zero configurazione manuale di routing
- CON: overhead operativo maggiore (4 Dockerfile, 4 pipeline, debug distribuito)
- CON: complessita di testing (contract test necessari)
- CON: consistenza dati piu complessa (no transazioni cross-schema)
- MITIGAZIONE: Docker Compose mantiene il deploy semplice (un comando)
- MITIGAZIONE: database condiviso elimina la complessita di sync dati
- MITIGAZIONE: CI/CD con matrix build riduce duplicazione pipeline

## Alternative considerate
1. **Rimanere Modular Monolith**: scartato perche non supporta job asincroni e scaling granulare
2. **Kubernetes**: scartato per overhead operativo sproporzionato per 1 persona su EC2
3. **Service mesh (Istio/Linkerd)**: scartato — Traefik copre routing e rate limiting sufficienti
