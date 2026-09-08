#!/bin/bash
# Cleanup script for Question 13 - Network Policy
set -uo pipefail
echo "Cleaning up Question 13: Network Policy..."

kubectl delete networkpolicy --all -n backend --ignore-not-found
kubectl delete namespace frontend --ignore-not-found
kubectl delete namespace backend --ignore-not-found
WORKDIR="${WORKDIR:-$PWD/network-policies}"
rm -rf "$WORKDIR"

echo "[OK] Question 13 cleanup complete"
