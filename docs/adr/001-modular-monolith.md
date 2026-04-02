# ADR-001: Modular Monolith invece di Microservizi

## Stato
Accettata

## Contesto
Il progetto FitnessAI ha 4 domini funzionali chiari (auth, workouts, ai, analytics) che potrebbero essere implementati come microservizi separati. Tuttavia, il progetto ha un singolo sviluppatore, infrastruttura limitata (AWS EC2 con Docker Compose), e obiettivo time-to-market di 4-5 mesi.

## Decisione
Implementiamo un backend FastAPI monolitico con 4 moduli interni ben separati, ciascuno con le proprie route, modelli, servizi e test. I moduli comunicano tramite import Python diretto, non via HTTP.

## Conseguenze
- PRO: deploy atomico, debugging semplice, nessun overhead di rete tra moduli
- PRO: ~40% meno effort di setup rispetto a microservizi
- PRO: singola pipeline CI/CD per il backend
- CON: non si scala un singolo modulo indipendentemente
- CON: un bug in un modulo puo crashare l'intero processo
- MITIGAZIONE: confini modulari chiari permettono estrazione futura in microservizi
- MITIGAZIONE: per la scala iniziale (10-50 utenti), il monolite e sufficiente

## Alternative considerate
1. Microservizi puri: scartati per overhead operativo sproporzionato
2. Microservizi ibridi: scartati perche Docker Compose non supporta service mesh
3. Monolite semplice (senza moduli): scartato perche rende difficile l'evoluzione futura
