#!/bin/bash
# Cleanup script for Question 6 - Container immutability
set -uo pipefail
echo "Cleaning up Question 6: Container immutability..."

kubectl delete deployment lamp-deployment -n lamp --ignore-not-found
kubectl delete namespace lamp --ignore-not-found

echo "[OK] Question 6 cleanup complete"
