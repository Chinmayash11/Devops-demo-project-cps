#!/bin/bash
# Backup script for Terraform state and application data
# Creates automated backups of critical data

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="terraform_state_${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "Creating backup: $BACKUP_FILE"

# Backup Terraform state from S3
aws s3 cp \
    "s3://$(terraform output -raw s3_bucket_name)/terraform.tfstate" \
    "$BACKUP_DIR/terraform_${TIMESTAMP}.tfstate"

# Create tarball
tar -czf "$BACKUP_DIR/$BACKUP_FILE" \
    terraform/environments/*/terraform.tfstate* \
    kubernetes/base/*.yaml \
    kubernetes/overlays/*/*.yaml

echo "Backup completed: $BACKUP_DIR/$BACKUP_FILE"
echo "Total backups: $(ls -1 $BACKUP_DIR | wc -l)"

# Cleanup old backups (keep only last 30 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete
echo "Cleanup completed - removed backups older than 30 days"
