#!/bin/bash
# FitnessAI — Daily PostgreSQL backup to S3
# Install: sudo cp backup-db.sh /etc/cron.daily/ && sudo chmod +x /etc/cron.daily/backup-db.sh
#
# Requires:
# - AWS CLI configured with S3 write access
# - S3_BACKUP_BUCKET environment variable set in /opt/fitnessai/.env

set -euo pipefail

# Configuration
APP_DIR="/opt/fitnessai"
BACKUP_DIR="/tmp/fitnessai-backups"
S3_BUCKET="${S3_BACKUP_BUCKET:-fitnessai-backups}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="fitnessai_db_${DATE}.sql.gz"
RETENTION_DAYS=30

# Load environment variables
if [ -f "${APP_DIR}/.env" ]; then
    set -a
    source "${APP_DIR}/.env"
    set +a
fi

DB_USER="${DB_USER:-fitnessai}"
DB_NAME="${DB_NAME:-fitness_ai}"

echo "[$(date)] Starting database backup..."

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Dump database (via Docker)
docker exec fitnessai-db pg_dump \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --no-owner \
    --no-acl \
    --format=plain \
    | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)
echo "[$(date)] Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# Upload to S3
aws s3 cp \
    "${BACKUP_DIR}/${BACKUP_FILE}" \
    "s3://${S3_BUCKET}/db-backups/${BACKUP_FILE}" \
    --storage-class STANDARD_IA

echo "[$(date)] Uploaded to s3://${S3_BUCKET}/db-backups/${BACKUP_FILE}"

# Clean up local backup
rm -f "${BACKUP_DIR}/${BACKUP_FILE}"

# Remove old S3 backups (older than RETENTION_DAYS)
aws s3 ls "s3://${S3_BUCKET}/db-backups/" \
    | awk '{print $4}' \
    | while read -r file; do
        file_date=$(echo "${file}" | grep -oP '\d{8}' | head -1)
        if [ -n "${file_date}" ]; then
            cutoff=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d)
            if [ "${file_date}" -lt "${cutoff}" ]; then
                aws s3 rm "s3://${S3_BUCKET}/db-backups/${file}"
                echo "[$(date)] Deleted old backup: ${file}"
            fi
        fi
    done

echo "[$(date)] Backup complete."
