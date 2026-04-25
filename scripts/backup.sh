#!/bin/bash
# ============================================
# VPS Backup & Restore Script
# ============================================
# Automated backup for databases and uploaded files
# Supports: MySQL, PostgreSQL, and file uploads
#
# Usage:
#   chmod +x scripts/backup.sh
#   ./scripts/backup.sh                          # Full backup
#   ./scripts/backup.sh --db-only                # Database only
#   ./scripts/backup.sh --files-only             # Files only
#   ./scripts/backup.sh --restore db latest      # Restore latest DB backup
#   ./scripts/backup.sh --restore files latest   # Restore latest files backup
#
# Cron Setup (daily at 2 AM):
#   crontab -e
#   0 2 * * * /path/to/scripts/backup.sh >> /var/log/backup.log 2>&1
#
# Weekly + Monthly (recommended):
#   0 2 * * *   /path/to/scripts/backup.sh                    # Daily
#   0 3 * * 0   /path/to/scripts/backup.sh --upload           # Weekly to remote
#   0 4 1 * *   /path/to/scripts/backup.sh --upload --monthly # Monthly
# ============================================

set -euo pipefail

# ============================================
# Configuration — EDIT THESE
# ============================================

# Backup directory
BACKUP_DIR="/var/backups/vps"
RETENTION_DAYS=30              # Delete backups older than this

# ---- MySQL ----
MYSQL_ENABLED=true
MYSQL_USER="root"
MYSQL_PASSWORD=""              # Leave empty to use ~/.my.cnf
MYSQL_DATABASES="all"          # "all" or space-separated: "db1 db2 db3"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"

# ---- PostgreSQL ----
POSTGRES_ENABLED=false
POSTGRES_USER="postgres"
POSTGRES_DATABASES="all"       # "all" or space-separated: "db1 db2 db3"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"

# ---- Docker Databases (if running in Docker) ----
DOCKER_ENABLED=false
DOCKER_MYSQL_CONTAINER="mysql"
DOCKER_POSTGRES_CONTAINER="postgres"

# ---- File Backups ----
FILES_ENABLED=true
# Directories to back up (space-separated)
BACKUP_PATHS="/var/www/apps/*/uploads /var/www/apps/*/storage/app /var/www/apps/*/public/uploads"

# ---- Remote Upload (optional) ----
# Supports: scp, rsync, s3
REMOTE_ENABLED=false
REMOTE_TYPE="s3"               # scp, rsync, s3
REMOTE_DEST=""                 # s3://bucket/backups OR user@host:/backups
AWS_PROFILE="default"          # For S3 uploads

# ---- Notifications (optional) ----
SLACK_WEBHOOK=""               # Slack webhook URL
NOTIFICATION_EMAIL=""          # Email for failure alerts

# ============================================
# DO NOT EDIT BELOW THIS LINE
# ============================================

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)
LOG_FILE="/var/log/backup-${DATE}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
success() { log "${GREEN}✅ $1${NC}"; }
warn() { log "${YELLOW}⚠️  $1${NC}"; }
error() { log "${RED}❌ $1${NC}"; }

notify_slack() {
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$1\"}" "$SLACK_WEBHOOK" > /dev/null 2>&1 || true
    fi
}

# Create backup directory structure
setup_dirs() {
    mkdir -p "$BACKUP_DIR/mysql"
    mkdir -p "$BACKUP_DIR/postgres"
    mkdir -p "$BACKUP_DIR/files"
    mkdir -p "$BACKUP_DIR/docker"
    log "Backup directory: $BACKUP_DIR"
}

# ============================================
# MySQL Backup
# ============================================
backup_mysql() {
    if [ "$MYSQL_ENABLED" != "true" ]; then return; fi

    log "📦 Starting MySQL backup..."

    local MYSQL_OPTS=""
    if [ -n "$MYSQL_PASSWORD" ]; then
        MYSQL_OPTS="-u${MYSQL_USER} -p${MYSQL_PASSWORD}"
    else
        MYSQL_OPTS="-u${MYSQL_USER}"
    fi
    MYSQL_OPTS="$MYSQL_OPTS -h${MYSQL_HOST} -P${MYSQL_PORT}"

    if [ "$MYSQL_DATABASES" = "all" ]; then
        local OUTFILE="$BACKUP_DIR/mysql/all-databases_${TIMESTAMP}.sql.gz"
        mysqldump $MYSQL_OPTS --all-databases --single-transaction --routines --triggers \
            | gzip > "$OUTFILE"
        success "MySQL (all databases) → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
    else
        for DB in $MYSQL_DATABASES; do
            local OUTFILE="$BACKUP_DIR/mysql/${DB}_${TIMESTAMP}.sql.gz"
            mysqldump $MYSQL_OPTS --single-transaction --routines --triggers "$DB" \
                | gzip > "$OUTFILE"
            success "MySQL ($DB) → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
        done
    fi
}

# ============================================
# PostgreSQL Backup
# ============================================
backup_postgres() {
    if [ "$POSTGRES_ENABLED" != "true" ]; then return; fi

    log "📦 Starting PostgreSQL backup..."

    if [ "$POSTGRES_DATABASES" = "all" ]; then
        local OUTFILE="$BACKUP_DIR/postgres/all-databases_${TIMESTAMP}.sql.gz"
        pg_dumpall -U "$POSTGRES_USER" -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" \
            | gzip > "$OUTFILE"
        success "PostgreSQL (all databases) → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
    else
        for DB in $POSTGRES_DATABASES; do
            local OUTFILE="$BACKUP_DIR/postgres/${DB}_${TIMESTAMP}.sql.gz"
            pg_dump -U "$POSTGRES_USER" -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" "$DB" \
                | gzip > "$OUTFILE"
            success "PostgreSQL ($DB) → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
        done
    fi
}

# ============================================
# Docker Database Backup
# ============================================
backup_docker_db() {
    if [ "$DOCKER_ENABLED" != "true" ]; then return; fi

    log "🐳 Starting Docker database backup..."

    # MySQL in Docker
    if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_MYSQL_CONTAINER}$" 2>/dev/null; then
        local OUTFILE="$BACKUP_DIR/docker/mysql_docker_${TIMESTAMP}.sql.gz"
        docker exec "$DOCKER_MYSQL_CONTAINER" mysqldump -u root -p"${MYSQL_PASSWORD}" --all-databases \
            | gzip > "$OUTFILE"
        success "Docker MySQL → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
    fi

    # PostgreSQL in Docker
    if docker ps --format '{{.Names}}' | grep -q "^${DOCKER_POSTGRES_CONTAINER}$" 2>/dev/null; then
        local OUTFILE="$BACKUP_DIR/docker/postgres_docker_${TIMESTAMP}.sql.gz"
        docker exec "$DOCKER_POSTGRES_CONTAINER" pg_dumpall -U "$POSTGRES_USER" \
            | gzip > "$OUTFILE"
        success "Docker PostgreSQL → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
    fi
}

# ============================================
# File Backup (uploads, storage)
# ============================================
backup_files() {
    if [ "$FILES_ENABLED" != "true" ]; then return; fi

    log "📁 Starting file backup..."

    local OUTFILE="$BACKUP_DIR/files/uploads_${TIMESTAMP}.tar.gz"
    local EXISTING_PATHS=""

    # Only include paths that actually exist
    for path_pattern in $BACKUP_PATHS; do
        for resolved in $path_pattern; do
            if [ -d "$resolved" ]; then
                EXISTING_PATHS="$EXISTING_PATHS $resolved"
            fi
        done
    done

    if [ -z "$EXISTING_PATHS" ]; then
        warn "No upload directories found to backup"
        return
    fi

    tar -czf "$OUTFILE" $EXISTING_PATHS 2>/dev/null || true
    success "Files → $(basename $OUTFILE) ($(du -sh "$OUTFILE" | cut -f1))"
}

# ============================================
# Remote Upload
# ============================================
upload_remote() {
    if [ "$REMOTE_ENABLED" != "true" ]; then return; fi

    log "☁️  Uploading to remote storage..."

    case "$REMOTE_TYPE" in
        s3)
            aws s3 sync "$BACKUP_DIR" "$REMOTE_DEST/${DATE}/" \
                --profile "$AWS_PROFILE" \
                --exclude "*.tmp"
            success "Uploaded to S3: $REMOTE_DEST/${DATE}/"
            ;;
        rsync)
            rsync -avz --delete "$BACKUP_DIR/" "$REMOTE_DEST/"
            success "Synced via rsync to $REMOTE_DEST"
            ;;
        scp)
            scp -r "$BACKUP_DIR/"*"_${TIMESTAMP}"* "$REMOTE_DEST/"
            success "Copied via SCP to $REMOTE_DEST"
            ;;
        *)
            error "Unknown remote type: $REMOTE_TYPE"
            ;;
    esac
}

# ============================================
# Cleanup Old Backups
# ============================================
cleanup() {
    log "🧹 Cleaning up backups older than ${RETENTION_DAYS} days..."

    local COUNT=0
    COUNT=$(find "$BACKUP_DIR" -type f -mtime +${RETENTION_DAYS} | wc -l)

    if [ "$COUNT" -gt 0 ]; then
        find "$BACKUP_DIR" -type f -mtime +${RETENTION_DAYS} -delete
        success "Deleted $COUNT old backup files"
    else
        log "No old backups to clean up"
    fi
}

# ============================================
# Restore Functions
# ============================================
restore_db() {
    local DB_TYPE="$1"
    local BACKUP_FILE="$2"

    # If "latest", find most recent backup
    if [ "$BACKUP_FILE" = "latest" ]; then
        BACKUP_FILE=$(ls -t "$BACKUP_DIR/$DB_TYPE/"*.sql.gz 2>/dev/null | head -1)
        if [ -z "$BACKUP_FILE" ]; then
            error "No $DB_TYPE backups found!"
            exit 1
        fi
    fi

    if [ ! -f "$BACKUP_FILE" ]; then
        error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi

    log "🔄 Restoring $DB_TYPE from: $(basename $BACKUP_FILE)"

    case "$DB_TYPE" in
        mysql)
            gunzip -c "$BACKUP_FILE" | mysql -u"$MYSQL_USER" ${MYSQL_PASSWORD:+-p"$MYSQL_PASSWORD"} \
                -h"$MYSQL_HOST" -P"$MYSQL_PORT"
            ;;
        postgres)
            gunzip -c "$BACKUP_FILE" | psql -U "$POSTGRES_USER" -h "$POSTGRES_HOST" -p "$POSTGRES_PORT"
            ;;
        docker)
            if echo "$BACKUP_FILE" | grep -q "mysql"; then
                gunzip -c "$BACKUP_FILE" | docker exec -i "$DOCKER_MYSQL_CONTAINER" mysql -u root -p"$MYSQL_PASSWORD"
            elif echo "$BACKUP_FILE" | grep -q "postgres"; then
                gunzip -c "$BACKUP_FILE" | docker exec -i "$DOCKER_POSTGRES_CONTAINER" psql -U "$POSTGRES_USER"
            fi
            ;;
    esac

    success "Restore complete!"
}

restore_files() {
    local BACKUP_FILE="$1"

    if [ "$BACKUP_FILE" = "latest" ]; then
        BACKUP_FILE=$(ls -t "$BACKUP_DIR/files/"*.tar.gz 2>/dev/null | head -1)
        if [ -z "$BACKUP_FILE" ]; then
            error "No file backups found!"
            exit 1
        fi
    fi

    log "🔄 Restoring files from: $(basename $BACKUP_FILE)"
    tar -xzf "$BACKUP_FILE" -C /
    success "File restore complete!"
}

# ============================================
# List Backups
# ============================================
list_backups() {
    echo ""
    echo "📋 Available Backups"
    echo "===================="

    for TYPE in mysql postgres docker files; do
        local DIR="$BACKUP_DIR/$TYPE"
        if [ -d "$DIR" ] && [ "$(ls -A "$DIR" 2>/dev/null)" ]; then
            echo ""
            echo "  [$TYPE]"
            ls -lhS "$DIR" | tail -n +2 | awk '{print "    " $NF " (" $5 ")"}'
        fi
    done

    echo ""
    echo "  Total size: $(du -sh "$BACKUP_DIR" | cut -f1)"
    echo ""
}

# ============================================
# Main
# ============================================
main() {
    local MODE="full"
    local UPLOAD=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db-only)    MODE="db"; shift ;;
            --files-only) MODE="files"; shift ;;
            --upload)     UPLOAD=true; shift ;;
            --monthly)    RETENTION_DAYS=365; shift ;;
            --restore)
                if [ "$2" = "db" ]; then
                    restore_db "${3:-mysql}" "${4:-latest}"
                elif [ "$2" = "files" ]; then
                    restore_files "${3:-latest}"
                else
                    error "Usage: --restore [db|files] [backup_file|latest]"
                fi
                exit 0
                ;;
            --list)       list_backups; exit 0 ;;
            --help|-h)
                echo "Usage: $(basename $0) [options]"
                echo ""
                echo "Options:"
                echo "  --db-only      Backup databases only"
                echo "  --files-only   Backup files only"
                echo "  --upload       Upload to remote storage"
                echo "  --monthly      Use 365-day retention"
                echo "  --restore db [mysql|postgres|docker] [file|latest]"
                echo "  --restore files [file|latest]"
                echo "  --list         List available backups"
                echo "  --help         Show this help"
                exit 0
                ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
    done

    log "=========================================="
    log "🚀 VPS Backup Started"
    log "=========================================="

    setup_dirs

    case "$MODE" in
        full)
            backup_mysql
            backup_postgres
            backup_docker_db
            backup_files
            ;;
        db)
            backup_mysql
            backup_postgres
            backup_docker_db
            ;;
        files)
            backup_files
            ;;
    esac

    cleanup

    if [ "$UPLOAD" = true ]; then
        upload_remote
    fi

    # Summary
    log "=========================================="
    log "✅ Backup Complete!"
    log "   Location: $BACKUP_DIR"
    log "   Size: $(du -sh "$BACKUP_DIR" | cut -f1)"
    log "=========================================="

    notify_slack "✅ VPS Backup complete — $(du -sh "$BACKUP_DIR" | cut -f1) total"
}

main "$@"
