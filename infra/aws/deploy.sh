#!/bin/bash
# FitnessAI — Production deployment script (backend)
# Runs ON the EC2 instance. Normally invoked by deploy-remote.sh from the dev
# PC, which also builds and uploads the Flutter PWA.
#
# Usage: ./deploy.sh [branch]
# Default branch: develop

set -euo pipefail

BRANCH="${1:-develop}"
APP_DIR="/opt/fitnessai"
BACKUP_DIR="/opt/fitnessai-backups"
COMPOSE="docker compose -f docker-compose.yml -f docker-compose.prod.yml"
# Services run in production ("web", the Next.js dashboard, is not deployed:
# the Flutter PWA owns the domain root)
SERVICES="traefik db redis auth workouts ai analytics pwa"
HEALTHCHECKED=("fitnessai-db" "fitnessai-redis" "fitnessai-auth" "fitnessai-workouts" "fitnessai-ai" "fitnessai-analytics")

echo "=== FitnessAI Deploy (branch: ${BRANCH}) ==="

cd "${APP_DIR}"

# 1. Align the checkout exactly to origin/<branch>. Local edits are never
#    supposed to exist on the server: if they do, save them as a patch first.
echo "[1/7] Aligning code to origin/${BRANCH}..."
git fetch origin
if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    PATCH="${HOME}/local-changes-$(date +%Y%m%d_%H%M%S).patch"
    git diff HEAD > "${PATCH}"
    echo "  Local changes saved to ${PATCH}"
fi
git checkout --force -B "${BRANCH}" "origin/${BRANCH}"
echo "  Commit: $(git log --oneline -1)"

# 2. Verify .env exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found. Copy .env.example and configure."
    exit 1
fi

# 3. Daily backup cron + pre-deploy backup
echo "[2/7] Backing up database..."
sudo mkdir -p "${BACKUP_DIR}"
sudo chown "$(id -un)" "${BACKUP_DIR}"
sudo install -m 755 infra/aws/backup-db.sh /etc/cron.daily/fitnessai-backup-db
if docker ps --format '{{.Names}}' | grep -q '^fitnessai-db$'; then
    BACKUP_DIR="${BACKUP_DIR}" ./infra/aws/backup-db.sh predeploy
else
    echo "  Database container not running: skipping backup (first deploy?)"
fi

# 4. Build images
echo "[3/7] Building containers..."
${COMPOSE} build auth workouts ai analytics

# 5. Database first, then SQL migrations (each applied once, in order)
echo "[4/7] Starting database and applying migrations..."
${COMPOSE} up -d db redis
for _ in $(seq 1 30); do
    [ "$(docker inspect --format='{{.State.Health.Status}}' fitnessai-db)" = "healthy" ] && break
    sleep 2
done
DB_USER=$(docker exec fitnessai-db printenv POSTGRES_USER)
DB_NAME=$(docker exec fitnessai-db printenv POSTGRES_DB)
PSQL="docker exec -i fitnessai-db psql -U ${DB_USER} -d ${DB_NAME} -v ON_ERROR_STOP=1 -q -At"
echo "CREATE TABLE IF NOT EXISTS public.deploy_migrations (
        name TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW());" | ${PSQL}
for f in $(ls services/*/migrations/*.sql 2>/dev/null | sort); do
    applied=$(echo "SELECT 1 FROM public.deploy_migrations WHERE name = '${f}';" | ${PSQL})
    if [ "${applied}" = "1" ]; then
        continue
    fi
    echo "  Applying ${f}"
    { echo "BEGIN;"; cat "${f}"; echo ";"
      echo "INSERT INTO public.deploy_migrations (name) VALUES ('${f}');"
      echo "COMMIT;"; } | ${PSQL}
done

# 6. Start everything with the new images
echo "[5/7] Starting services..."
${COMPOSE} up -d ${SERVICES}

# 7. Wait for health checks (up to 2 minutes)
echo "[6/7] Waiting for services to be healthy..."
ALL_HEALTHY=false
for _ in $(seq 1 24); do
    ALL_HEALTHY=true
    for svc in "${HEALTHCHECKED[@]}"; do
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${svc}" 2>/dev/null || echo "no-container")
        [ "${STATUS}" = "healthy" ] || ALL_HEALTHY=false
    done
    [ "${ALL_HEALTHY}" = true ] && break
    sleep 5
done
for svc in "${HEALTHCHECKED[@]}"; do
    echo "  ${svc}: $(docker inspect --format='{{.State.Health.Status}}' "${svc}" 2>/dev/null || echo "no-container")"
done

# Remove dangling images left by the rebuild
docker image prune -f >/dev/null

# 8. Report
echo ""
echo "[7/7] Deploy summary"
echo "  Branch: ${BRANCH}"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Time:   $(date)"

if [ "${ALL_HEALTHY}" = true ]; then
    echo "  Status: ALL SERVICES HEALTHY"
else
    echo "  Status: SOME SERVICES UNHEALTHY — check logs"
    echo "  Debug:  ${COMPOSE} logs --tail=50"
    exit 1
fi

echo ""
echo "=== Deploy Complete ==="
