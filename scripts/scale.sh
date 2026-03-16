#!/bin/bash
set -e

# Runtime Script: scale.sh
# Manually scales a deployment for emergency scenarios.
# Temporarily suspends the HPA, scales to the requested replica count,
# then restores the HPA so autoscaling resumes automatically.

NAMESPACE="node-3tier-app"

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

HPA_NAME="${TIER}-hpa"
DEPLOY_NAME="${TIER}-deployment"

echo "Scaling the ${TIER} deployment to ${REPLICAS} replicas..."

# 1. Suspend the HPA so it doesn't fight the manual scale
echo "Suspending HPA ${HPA_NAME}..."
kubectl patch hpa "${HPA_NAME}" -n "${NAMESPACE}" \
  -p '{"spec":{"minReplicas":'"${REPLICAS}"',"maxReplicas":'"${REPLICAS}"'}}'

# 2. Scale the deployment
kubectl scale deployment "${DEPLOY_NAME}" --replicas="${REPLICAS}" -n "${NAMESPACE}"

echo ""
echo "Scaled to ${REPLICAS}. Current pods:"
kubectl get pods -l "app=${TIER}" -n "${NAMESPACE}"

echo ""
echo "NOTE: HPA is patched to fixed replicas=${REPLICAS}."
echo "To restore autoscaling (2-10 replicas), run:"
echo "  kubectl patch hpa ${HPA_NAME} -n ${NAMESPACE} -p '{\"spec\":{\"minReplicas\":2,\"maxReplicas\":10}}'"
