#!/bin/bash
set -e

# ==============================================================================
# Runtime Script: scale.sh
# ==============================================================================
# Manually scales a deployment bypassing the HPA bounds for emergency scenarios.

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./scale.sh <tier> <replicas>"
  echo "Example: ./scale.sh web 5"
  exit 1
fi

TIER=$1
REPLICAS=$2

if [ "$TIER" != "web" ] && [ "$TIER" != "api" ]; then
  echo "Invalid tier. Must be 'web' or 'api'."
  exit 1
fi

echo "Scaling the ${TIER} deployment to ${REPLICAS} replicas..."

# 1. We must pause/remove the HPA temporarily so it doesn't fight our manual scaling
echo "Suspending HPA for ${TIER}..."
kubectl delete hpa ${TIER}-hpa -n node-3tier-app --ignore-not-found

# 2. Scale the deployment explicitly
kubectl scale deployment ${TIER}-deployment --replicas=${REPLICAS} -n node-3tier-app

echo ""
echo "Scale command executed. Current pods:"
kubectl get pods -l app=${TIER} -n node-3tier-app
