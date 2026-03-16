#!/bin/bash
set -e

# Runtime Script: start.sh
# Applies all Kubernetes manifests using Kustomize and waits for pod readiness.

NAMESPACE="node-3tier-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Starting node-3tier-app..."

# 1. Apply namespace first (must exist before kustomize apply)
kubectl apply -f "${REPO_ROOT}/k8s/base/namespace.yaml"

# 2. Apply all manifests via Kustomize (dev overlay)
kubectl apply -k "${REPO_ROOT}/k8s/overlays/dev/"

echo "Kubernetes manifests applied."
echo "Waiting for pods to become ready..."

kubectl wait --for=condition=ready pod -l app=web -n "${NAMESPACE}" --timeout=180s
kubectl wait --for=condition=ready pod -l app=api -n "${NAMESPACE}" --timeout=180s

echo ""
echo "Application started successfully. Current pod status:"
kubectl get pods -n "${NAMESPACE}"
