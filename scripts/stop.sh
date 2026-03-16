#!/bin/bash
set -e

# Runtime Script: stop.sh
# Deletes all application Kubernetes resources (namespace, deployments, services,
# HPA, TargetGroupBinding). Does NOT destroy infrastructure (Terraform).

NAMESPACE="node-3tier-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Stopping node-3tier-app..."

kubectl delete -k "${REPO_ROOT}/k8s/overlays/dev/" --ignore-not-found
kubectl delete -f "${REPO_ROOT}/k8s/base/namespace.yaml" --ignore-not-found

echo "Application stopped successfully."
