#!/bin/bash
set -e

# ==============================================================================
# Runtime Script: start.sh
# ==============================================================================
# This script applies all Kubernetes manifests to start the application.

echo "Starting node-3tier-app..."

# 1. Apply the namespace first
kubectl apply -f ../k8s/01-namespace.yaml

# 2. Apply all other manifests
kubectl apply -f ../k8s/

echo "Kubernetes manifests applied."
echo "Waiting for pods to become ready..."

kubectl wait --for=condition=ready pod -l app=web -n node-3tier-app --timeout=120s
kubectl wait --for=condition=ready pod -l app=api -n node-3tier-app --timeout=120s

echo ""
echo "Application started successfully! Current pod status:"
kubectl get pods -n node-3tier-app
