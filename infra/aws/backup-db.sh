#!/bin/bash
# FitnessAI — PostgreSQL backup
# Installed by deploy.sh in /etc/cron.daily/fitnessai-backup-db (daily) and
# also run by deploy.sh before every deploy.
#
# Backups are kept in BACKUP_DIR for RETENTION_DAYS days. If S3_BACKUP_BUCKET
# is set in /opt/fitnessai/.env and the AWS CLI is installed, each backup is
# also uploaded to S3.
#
# Usage: backup-db.sh [label]   (label is appended to the file name)

set -euo pipefail

# Configuration
APP_DIR="/opt/fitnessai"
BACKUP_DIR="${BACKUP_DIR:-/opt/fitnessai-backups}"
DATE=$(date +%Y%m%d_%H%M%S)
LABEL="${1:+_$1}"
BACKUP_FILE="fitnessai_db_${DATE}${LABEL}.sql.gz"
RETENTION_DAYS=14

# Load environment variables
if [ -f "${APP_DIR}/.env" ]; then
    set -a
    source "${APP_DIR}/.env"
    set +a
fi

# Credentials as configured in the db container itself
DB_USER=$(docker exec fitnessai-db printenv POSTGRES_USER)
DB_NAME=$(docker exec fitnessai-db printenv POSTGRES_DB)

echo "[$(date)] Starting database backup..."

mkdir -p "${BACKUP_DIR}"

# Dump database (via Docker); write to a temp file so a failed dump never
# leaves a truncated backup behind
docker exec fitnessai-db pg_dump \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --no-owner \
    --no-acl \
    --format=plain \
    | gzip > "${BACKUP_DIR}/${BACKUP_FILE}.tmp"
mv "${BACKUP_DIR}/${BACKUP_FILE}.tmp" "${BACKUP_DIR}/${BACKUP_FILE}"

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
echo "[$(date)] Backup created: ${BACKUP_DIR}/${BACKUP_FILE} (${BACKUP_SIZE})"

# Optional upload to S3
if [ -n "${S3_BACKUP_BUCKET:-}" ] && command -v aws >/dev/null 2>&1; then
    aws s3 cp \
        "${BACKUP_DIR}/${BACKUP_FILE}" \
        "s3://${S3_BACKUP_BUCKET}/db-backups/${BACKUP_FILE}" \
        --storage-class STANDARD_IA
    echo "[$(date)] Uploaded to s3://${S3_BACKUP_BUCKET}/db-backups/${BACKUP_FILE}"
fi

# Remove local backups older than RETENTION_DAYS
find "${BACKUP_DIR}" -name 'fitnessai_db_*.sql.gz' -mtime +"${RETENTION_DAYS}" -print -delete

echo "[$(date)] Backup complete."
