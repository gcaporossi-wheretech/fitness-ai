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
    +-- nginx:1.25 (porta 80, 443)
    +-- api (FastAPI, porta 8000, internal only)
    +-- web (Next.js, porta 3000, internal only)
    +-- db (PostgreSQL 16, porta 5432, internal only)
```

## Deploy flow
1. Push su `develop` -> GitHub Actions pipeline (test + build)
2. Merge da `develop` a `main` -> pipeline completa + build Docker images
3. SSH su EC2 -> `docker compose pull && docker compose up -d`
4. Health check automatico -> rollback se /health non risponde entro 30s

## Backup
- PostgreSQL: pg_dump giornaliero -> S3 bucket (retention 30 giorni)
- Script in `infra/backup.sh`
- Restore testato mensilmente

## Scaling plan
- Fase 1 (0-50 utenti): EC2 t3.small, tutto su una macchina
- Fase 2 (50-500 utenti): EC2 t3.medium, RDS per database separato
- Fase 3 (500+ utenti): estrarre modulo AI come servizio separato, load balancer

## SSL/TLS
- Let's Encrypt con certbot
- Auto-renewal via cron job
- Redirect HTTP -> HTTPS in Nginx

## Monitoring in produzione
- Docker healthcheck su ogni container
- CloudWatch basic metrics (CPU, memoria, disco)
- Structured JSON logs -> CloudWatch Logs
- Alerting: CloudWatch Alarm se CPU > 80% per 5 min
