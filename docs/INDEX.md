# FitnessAI — Indice documentazione

## Panoramica progetto
- [Project Brief](PROJECT_BRIEF.md) — Obiettivo, ambito, stack, rischi

## Architettura
- [Overview e diagrammi C4](architecture/overview.md) — Container, microservizi, comunicazione, Traefik routing
- [Specifiche servizi](architecture/services.md) — auth, workouts, ai, analytics (API + DB schema + sicurezza)

## Sicurezza
- [Security Architecture](security/security-architecture.md) — Auth, secrets, network, data protection, rate limiting

## Specifiche tecniche
- [API Contract](specs/api-contract.md) — Tutti gli endpoint con formato richiesta/risposta
- [Database Schema](specs/database-schema.md) — Tabelle, relazioni, indici, migrazione
- [Deploy Strategy](specs/deploy-strategy.md) — Ambienti, Docker Compose, Traefik, backup, scaling

## Decisioni architetturali (ADR)
- [ADR-001: Modular Monolith](adr/001-modular-monolith.md) — (Superata) Architettura iniziale
- [ADR-002: Offline-First Sync](adr/002-offline-first-sync.md) — Last-write-wins strategy
- [ADR-003: AI Photo Privacy](adr/003-ai-photo-privacy.md) — Foto mai salvate su disco
- [ADR-004: Microservices Architecture](adr/004-microservices-architecture.md) — Migrazione a microservizi con Traefik e Redis

## Riferimenti
- [Glossario](GLOSSARY.md) — Termini chiave del progetto
