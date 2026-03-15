#!/bin/bash
set -e

# ==============================================================================
# Runtime Script: deploy.sh
# ==============================================================================
# Triggers a rolling update manually by patching the deployment timestamp,
# pulling the latest `:latest` image tag if it was pushed to ECR.

if [ -z "$1" ]; then
  echo "Usage: ./deploy.sh <tier>"
  echo "Example: ./deploy.sh web"
  exit 1
fi

TIER=$1

if [ "$TIER" != "web" ] && [ "$TIER" != "api" ]; then
  echo "Invalid tier. Must be 'web' or 'api'."
  exit 1
fi

echo "Triggering a rolling deployment for the ${TIER} tier..."

# Trigger rollout by applying an annotation (Kubernetes native restart)
kubectl rollout restart deployment ${TIER}-deployment -n node-3tier-app

# Watch the rollout status
kubectl rollout status deployment ${TIER}-deployment -n node-3tier-app --timeout=120s

echo ""
echo "Deployment successful! Zero-downtime rolling update completed."
