# Glossario — FitnessAI

| Termine | Definizione |
|---------|------------|
| **AI Coach** | Feature che genera schede personalizzate analizzando foto corporee + dati utente |
| **AI Vision** | Feature che riconosce macchinari da foto e suggerisce esercizi |
| **Client ID** | UUID generato dal client mobile per ogni entita, usato per dedup durante sync |
| **Credits** | Valuta interna per limitare l'uso delle feature AI (1 credit = 1 scan, 5 credits = 1 scheda) |
| **Exercise type** | Tipo di esercizio: weighted (kg+rep), timed (secondi), bodyweight (solo rep) |
| **Microservizi** | Architettura backend corrente: 4 servizi FastAPI indipendenti (auth, workouts, ai, analytics) orchestrati con Docker Compose |
| **Modular Monolith** | Architettura backend precedente (ADR-001, superata): singolo processo con moduli interni |
| **Redis Streams** | Coda messaggi Redis per job AI asincroni (vision scan, coach generation) |
| **Traefik** | API Gateway: routing path-based, HTTPS auto, rate limiting, auto-discovery via Docker labels |
| **Offline-first** | Paradigma: l'app funziona completamente senza rete, sincronizza quando possibile |
| **RPE** | Rate of Perceived Exertion — scala 1-10 di fatica percepita |
| **Scheda** | Piano di allenamento strutturato (workout plan) con giorni, esercizi, set, rep |
| **Session** | Singolo allenamento completato con log di tutti gli esercizi/set effettuati |
| **Sync** | Processo di sincronizzazione dati tra app mobile (Hive) e backend (PostgreSQL) |
| **Vertical slice** | Un flusso end-to-end funzionante anche se minimo (dalla UI al database) |
