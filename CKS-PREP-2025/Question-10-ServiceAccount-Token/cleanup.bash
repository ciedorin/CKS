#!/bin/bash
# Cleanup script for Question 10 - ServiceAccount token
set -uo pipefail
echo "Cleaning up Question 10: ServiceAccount token..."

kubectl delete deployment stats-monitor -n monitoring --ignore-not-found
kubectl delete serviceaccount stats-monitor-sa -n monitoring --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

echo "[OK] Question 10 cleanup complete"
