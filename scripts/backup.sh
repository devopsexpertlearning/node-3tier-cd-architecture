#!/bin/bash
set -e

# ==============================================================================
# Backup Script: backup.sh
# ==============================================================================
# Manages Velero backups for Kubernetes state (node-3tier-app namespace).
# RDS automated backups run independently via AWS (7-day retention, 03:00 UTC).
#
# NOTE: Velero daily schedule is disabled in tfvars (enable_velero_schedule=false).
#       Use 'create' for on-demand backups or enable the schedule via Terraform.
#
# Usage:
#   ./backup.sh create              - Trigger an on-demand Velero backup
#   ./backup.sh list                - List all Velero backups and their status
#   ./backup.sh status <name>       - Show details of a specific backup
#   ./backup.sh restore <name>      - Restore from a named Velero backup
#   ./backup.sh rds-snapshots       - List RDS automated snapshots via AWS CLI

APP_NAMESPACE="node-3tier-app"
RDS_INSTANCE_ID="node-3tier-dev-postgres"

check_velero() {
  if ! command -v velero &>/dev/null; then
    echo "Error: 'velero' CLI not found."
    echo "Install: https://velero.io/docs/latest/basic-install/"
    exit 1
  fi
}

check_kubectl() {
  if ! command -v kubectl &>/dev/null; then
    echo "Error: 'kubectl' CLI not found."
    exit 1
  fi
  echo "kubectl context: $(kubectl config current-context)"
}

usage() {
  echo "Usage: ./backup.sh <command> [args]"
  echo ""
  echo "Commands:"
  echo "  create                  Trigger an on-demand Velero backup"
  echo "  list                    List all backups and their status"
  echo "  status <backup-name>    Show details of a specific backup"
  echo "  restore <backup-name>   Restore cluster state from a backup"
  echo "  rds-snapshots           List RDS automated snapshots (requires AWS CLI)"
  exit 1
}

if [ -z "$1" ]; then
  usage
fi

COMMAND=$1

case "$COMMAND" in

  create)
    check_velero
    check_kubectl
    BACKUP_NAME="manual-$(date +%Y%m%d-%H%M%S)"
    echo "Creating Velero backup: ${BACKUP_NAME}..."
    velero backup create "${BACKUP_NAME}" \
      --include-namespaces "${APP_NAMESPACE}" \
      --include-cluster-resources=true \
      --wait
    echo ""
    echo "Backup completed. Status:"
    velero backup describe "${BACKUP_NAME}" --details
    ;;

  list)
    check_velero
    echo "All Velero backups:"
    velero backup get
    ;;

  status)
    check_velero
    if [ -z "$2" ]; then
      echo "Error: backup name required."
      echo "Usage: ./backup.sh status <backup-name>"
      exit 1
    fi
    velero backup describe "$2" --details
    ;;

  restore)
    check_velero
    check_kubectl
    if [ -z "$2" ]; then
      echo "Error: backup name required."
      echo "Usage: ./backup.sh restore <backup-name>"
      exit 1
    fi
    RESTORE_NAME="restore-$2-$(date +%H%M%S)"
    echo "Restoring from backup: $2 (restore name: ${RESTORE_NAME})..."
    velero restore create "${RESTORE_NAME}" --from-backup "$2" --wait
    echo ""
    echo "Restore completed. Status:"
    velero restore describe "${RESTORE_NAME}"
    ;;

  rds-snapshots)
    if ! command -v aws &>/dev/null; then
      echo "Error: AWS CLI not found. Install it and configure credentials."
      exit 1
    fi
    echo "RDS automated snapshots for ${RDS_INSTANCE_ID}:"
    aws rds describe-db-snapshots \
      --db-instance-identifier "${RDS_INSTANCE_ID}" \
      --snapshot-type automated \
      --query "DBSnapshots[*].{ID:DBSnapshotIdentifier,Created:SnapshotCreateTime,Status:Status,SizeGB:AllocatedStorage}" \
      --output table
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
