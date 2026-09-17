#!/bin/bash
# Cleanup script for Question 13 - Pod Security Standards
set -uo pipefail
echo "Cleaning up Question 13: Pod Security Standards..."

kubectl delete deployment confidential-app -n confidential --ignore-not-found
kubectl delete namespace confidential --ignore-not-found

echo "[OK] Question 13 cleanup complete"
