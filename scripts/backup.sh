#!/bin/bash

# AnimaGenius Database Backup Script
set -euo pipefail

# Configuration
CLUSTER_NAME="animagenius-production"
AWS_REGION="us-east-1"
NAMESPACE="animagenius-production"
BACKUP_BUCKET="animagenius-backups-production"
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Get database credentials from Kubernetes secrets
get_db_credentials() {
    log "Retrieving database credentials..."
    
    DB_HOST=$(kubectl get secret animagenius-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_HOST}' | base64 -d)
    DB_USERNAME=$(kubectl get secret animagenius-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_USERNAME}' | base64 -d)
    DB_PASSWORD=$(kubectl get secret animagenius-secrets -n "$NAMESPACE" -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
    DB_NAME=$(kubectl get configmap animagenius-config -n "$NAMESPACE" -o jsonpath='{.data.DB_NAME}')
    
    export PGPASSWORD="$DB_PASSWORD"
    
    success "Database credentials retrieved"
}

# Create database backup
create_database_backup() {
    log "Creating database backup..."
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="animagenius_backup_${timestamp}.sql"
    local compressed_backup="${backup_file}.gz"
    
    # Create backup directory
    mkdir -p /tmp/backups
    cd /tmp/backups
    
    # Create database dump
    if pg_dump -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" \
        --verbose --clean --no-owner --no-privileges \
        --format=custom --file="$backup_file"; then
        success "Database dump created: $backup_file"
    else
        error "Failed to create database dump"
        return 1
    fi
    
    # Compress backup
    if gzip "$backup_file"; then
        success "Backup compressed: $compressed_backup"
    else
        error "Failed to compress backup"
        return 1
    fi
    
    # Upload to S3
    local s3_path="s3://$BACKUP_BUCKET/database/$(date +%Y)/$(date +%m)/$compressed_backup"
    if aws s3 cp "$compressed_backup" "$s3_path" --storage-class STANDARD_IA; then
        success "Backup uploaded to S3: $s3_path"
    else
        error "Failed to upload backup to S3"
        return 1
    fi
    
    # Clean up local files
    rm -f "$compressed_backup"
    
    echo "$s3_path"
}

# Backup Redis data
backup_redis() {
    log "Creating Redis backup..."
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="redis_backup_${timestamp}.rdb"
    
    # Get Redis connection details
    local redis_host
    redis_host=$(kubectl get configmap animagenius-config -n "$NAMESPACE" -o jsonpath='{.data.REDIS_HOST}')
    
    # Create Redis backup using kubectl exec
    if kubectl exec -n "$NAMESPACE" deployment/animagenius-api -- \
        redis-cli -h "$redis_host" --rdb /tmp/"$backup_file"; then
        
        # Copy backup from pod
        kubectl cp "$NAMESPACE"/$(kubectl get pods -n "$NAMESPACE" -l component=api -o jsonpath='{.items[0].metadata.name}'):/tmp/"$backup_file" \
            /tmp/backups/"$backup_file"
        
        # Compress and upload
        gzip /tmp/backups/"$backup_file"
        local s3_path="s3://$BACKUP_BUCKET/redis/$(date +%Y)/$(date +%m)/${backup_file}.gz"
        aws s3 cp "/tmp/backups/${backup_file}.gz" "$s3_path" --storage-class STANDARD_IA
        
        success "Redis backup uploaded to S3: $s3_path"
        rm -f "/tmp/backups/${backup_file}.gz"
    else
        warn "Redis backup failed - continuing with other backups"
    fi
}

# Backup application data from S3
backup_application_data() {
    log "Creating application data backup..."
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local source_bucket="animagenius-videos-production"
    local backup_path="s3://$BACKUP_BUCKET/application-data/$(date +%Y)/$(date +%m)/videos_$timestamp/"
    
    # Sync videos to backup bucket
    if aws s3 sync "s3://$source_bucket" "$backup_path" --storage-class GLACIER; then
        success "Application data backed up to: $backup_path"
    else
        warn "Application data backup failed"
    fi
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local cutoff_date
    cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
    
    # Clean up database backups
    aws s3api list-objects-v2 --bucket "$BACKUP_BUCKET" --prefix "database/" --query "Contents[?LastModified<='$cutoff_date'].Key" --output text | \
    while read -r key; do
        if [[ -n "$key" ]]; then
            aws s3 rm "s3://$BACKUP_BUCKET/$key"
            log "Deleted old backup: $key"
        fi
    done
    
    # Clean up Redis backups
    aws s3api list-objects-v2 --bucket "$BACKUP_BUCKET" --prefix "redis/" --query "Contents[?LastModified<='$cutoff_date'].Key" --output text | \
    while read -r key; do
        if [[ -n "$key" ]]; then
            aws s3 rm "s3://$BACKUP_BUCKET/$key"
            log "Deleted old Redis backup: $key"
        fi
    done
    
    success "Old backups cleaned up"
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"
    
    log "Verifying backup integrity..."
    
    # Download and test the backup
    local temp_file="/tmp/backup_verify.sql.gz"
    if aws s3 cp "$backup_path" "$temp_file"; then
        if gunzip -t "$temp_file"; then
            success "Backup integrity verified"
            rm -f "$temp_file"
            return 0
        else
            error "Backup integrity check failed"
            rm -f "$temp_file"
            return 1
        fi
    else
        error "Failed to download backup for verification"
        return 1
    fi
}

# Send backup notification
send_notification() {
    local status="$1"
    local backup_path="$2"
    local message
    
    if [[ "$status" == "success" ]]; then
        message="✅ AnimaGenius backup completed successfully. Backup location: $backup_path"
    else
        message="❌ AnimaGenius backup failed. Please check the logs."
    fi
    
    # Send to SNS topic (if configured)
    if [[ -n "${SNS_TOPIC_ARN:-}" ]]; then
        aws sns publish --topic-arn "$SNS_TOPIC_ARN" --message "$message" --subject "AnimaGenius Backup Status"
    fi
    
    # Log the message
    if [[ "$status" == "success" ]]; then
        success "$message"
    else
        error "$message"
    fi
}

# Restore database from backup
restore_database() {
    local backup_path="$1"
    
    warn "This will restore the database from backup: $backup_path"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log "Restore cancelled"
        return 0
    fi
    
    log "Restoring database from backup..."
    
    # Download backup
    local temp_file="/tmp/restore_backup.sql.gz"
    if ! aws s3 cp "$backup_path" "$temp_file"; then
        error "Failed to download backup"
        return 1
    fi
    
    # Decompress
    if ! gunzip "$temp_file"; then
        error "Failed to decompress backup"
        return 1
    fi
    
    # Restore database
    if pg_restore -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" \
        --verbose --clean --no-owner --no-privileges \
        "${temp_file%.gz}"; then
        success "Database restored successfully"
        rm -f "${temp_file%.gz}"
    else
        error "Database restore failed"
        rm -f "${temp_file%.gz}"
        return 1
    fi
}

# Main backup function
main() {
    local operation="${1:-backup}"
    
    case "$operation" in
        "backup")
            log "Starting full backup process..."
            
            # Ensure backup directory exists
            mkdir -p /tmp/backups
            
            # Get credentials
            get_db_credentials
            
            # Create backups
            local db_backup_path
            if db_backup_path=$(create_database_backup); then
                verify_backup "$db_backup_path"
                backup_redis
                backup_application_data
                cleanup_old_backups
                send_notification "success" "$db_backup_path"
            else
                send_notification "failed" ""
                exit 1
            fi
            
            # Cleanup
            rm -rf /tmp/backups
            
            success "Backup process completed successfully"
            ;;
            
        "restore")
            if [[ -z "${2:-}" ]]; then
                error "Please provide backup S3 path for restore"
                exit 1
            fi
            get_db_credentials
            restore_database "$2"
            ;;
            
        "list")
            log "Listing available backups..."
            aws s3 ls "s3://$BACKUP_BUCKET/database/" --recursive --human-readable
            ;;
            
        "verify")
            if [[ -z "${2:-}" ]]; then
                error "Please provide backup S3 path for verification"
                exit 1
            fi
            verify_backup "$2"
            ;;
            
        *)
            error "Invalid operation. Usage: $0 [backup|restore|list|verify] [backup-path]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"