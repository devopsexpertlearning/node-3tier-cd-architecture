#!/bin/bash
set -e

# ==============================================================================
# Runtime Script: stop.sh
# ==============================================================================
# This script deletes all Kubernetes resources for the application.

echo "Stopping node-3tier-app..."

kubectl delete -f ../k8s/

echo "Application stopped successfully."
