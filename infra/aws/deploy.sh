#!/bin/bash
# FitnessAI — Production deployment script
# Run from the EC2 instance after initial setup
#
# Usage: ./deploy.sh [branch]
# Default branch: main

set -euo pipefail

BRANCH="${1:-main}"
APP_DIR="/opt/fitnessai"

echo "=== FitnessAI Deploy (branch: ${BRANCH}) ==="

cd "${APP_DIR}"

# 1. Pull latest code
echo "[1/5] Pulling latest code..."
git fetch origin
git checkout "${BRANCH}"
git pull origin "${BRANCH}"

# 2. Verify .env exists
if [ ! -f .env ]; then
    echo "ERROR: .env file not found. Copy .env.example and configure."
    exit 1
fi

# 3. Build and deploy
echo "[2/5] Building containers..."
docker compose -f docker-compose.yml -f docker-compose.prod.yml build

echo "[3/5] Starting services..."
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 4. Wait for health checks
echo "[4/5] Waiting for services to be healthy..."
sleep 10

SERVICES=("fitnessai-auth" "fitnessai-workouts" "fitnessai-ai" "fitnessai-analytics" "fitnessai-db" "fitnessai-redis")
ALL_HEALTHY=true

for svc in "${SERVICES[@]}"; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${svc}" 2>/dev/null || echo "no-container")
    if [ "${STATUS}" = "healthy" ]; then
        echo "  ${svc}: healthy"
    else
        echo "  ${svc}: ${STATUS}"
        ALL_HEALTHY=false
    fi
done

# 5. Report
echo ""
echo "[5/5] Deploy summary"
echo "  Branch: ${BRANCH}"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Time:   $(date)"

if [ "${ALL_HEALTHY}" = true ]; then
    echo "  Status: ALL SERVICES HEALTHY"
else
    echo "  Status: SOME SERVICES UNHEALTHY — check logs"
    echo "  Debug:  docker compose logs --tail=50"
fi

echo ""
echo "=== Deploy Complete ==="
