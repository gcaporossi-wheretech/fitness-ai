# Deploy Strategy — FitnessAI

## Ambienti

| Ambiente | Infrastruttura | URL | Scopo |
|----------|---------------|-----|-------|
| Local | Docker Compose | localhost | Sviluppo |
| Production | AWS EC2 t3.small | fitnessai.app | Produzione |

## Architettura di deploy

```
AWS EC2 (t3.small, ~15$/mese)
+-- Docker Compose
    +-- traefik:v3 (porta 80, 443) — API Gateway
    +-- auth (FastAPI, porta 8001, internal only)
    +-- workouts (FastAPI, porta 8002, internal only)
    +-- ai (FastAPI, porta 8003, internal only)
    +-- analytics (FastAPI, porta 8004, internal only)
    +-- db (PostgreSQL 16, porta 5432, internal only)
    +-- redis (Redis 7, porta 6379, internal only)
    +-- web (Next.js, porta 3000, internal only)
```

## Routing (Traefik path-based)

| Path prefix | Servizio | Porta |
|-------------|----------|-------|
| /auth/* | auth | 8001 |
| /workouts/* | workouts | 8002 |
| /ai/* | ai | 8003 |
| /analytics/* | analytics | 8004 |
| /* (fallback) | web | 3000 |

## Deploy flow
1. Push su `develop` -> GitHub Actions pipeline (lint + test + security per ogni servizio)
2. Merge da `develop` a `main` -> pipeline completa + build Docker images per tutti i servizi
3. SSH su EC2 -> `cd /opt/fitnessai && ./infra/aws/deploy.sh main`
4. Health check automatico per ogni servizio -> rollback se qualsiasi /health non risponde entro 30s
5. Rolling update: aggiornare un servizio alla volta per minimizzare downtime

## Initial EC2 Setup
```bash
# On a fresh Ubuntu 24.04 LTS EC2 instance (t3.small):
scp infra/aws/setup-ec2.sh ubuntu@<IP>:~
ssh ubuntu@<IP> bash setup-ec2.sh

# Then clone and configure:
cd /opt/fitnessai
git clone https://github.com/gcaporossi-wheretech/fitness-ai .
cp .env.example .env
# Edit .env with production values (JWT_SECRET, ANTHROPIC_API_KEY, DB_PASSWORD, DOMAIN)
./infra/aws/deploy.sh main
```

## Deploy script
`infra/aws/deploy.sh [branch]` — pulls code, builds, starts, verifies health.

## Backup script
`infra/aws/backup-db.sh` — daily pg_dump to S3, 30-day retention.
Install: `sudo cp infra/aws/backup-db.sh /etc/cron.daily/ && sudo chmod +x /etc/cron.daily/backup-db.sh`

## Backup
- PostgreSQL: pg_dump giornaliero -> S3 bucket (retention 30 giorni)
- Redis: appendonly file, backup settimanale
- Script in `infra/backup.sh`
- Restore testato mensilmente

## Scaling plan
- Fase 1 (0-50 utenti): EC2 t3.small, tutto su una macchina
- Fase 2 (50-500 utenti): EC2 t3.medium, RDS per database separato
- Fase 3 (500+ utenti): servizio AI su istanza separata (GPU-enabled), load balancer

## SSL/TLS
- Let's Encrypt con Traefik ACME (auto-renewal integrato)
- TLS 1.2+ minimo
- Redirect HTTP -> HTTPS via Traefik entrypoint

## Monitoring in produzione
- Docker healthcheck su ogni container
- Traefik dashboard per routing e metriche HTTP
- CloudWatch basic metrics (CPU, memoria, disco)
- Structured JSON logs -> CloudWatch Logs (un log group per servizio)
- Alerting: CloudWatch Alarm se CPU > 80% per 5 min
- Redis: MONITOR per debug, INFO per metriche
