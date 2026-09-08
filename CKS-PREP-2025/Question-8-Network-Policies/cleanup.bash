#!/bin/bash
# Cleanup script for Question 8 - NetworkPolicies
set -uo pipefail
echo "Cleaning up Question 8: NetworkPolicies..."

kubectl delete networkpolicy --all -n prod --ignore-not-found
kubectl delete networkpolicy --all -n data --ignore-not-found
kubectl delete namespace prod --ignore-not-found
kubectl delete namespace data --ignore-not-found
kubectl delete namespace other --ignore-not-found
rm -f deny-policy.yaml allow-from-prod.yaml

echo "[OK] Question 8 cleanup complete"
