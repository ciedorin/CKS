#!/bin/bash
# Cleanup script for Question 15 - Istio mTLS
set -uo pipefail
echo "Cleaning up Question 15: Istio mTLS..."

kubectl delete peerauthentication --all -n mtls --ignore-not-found
kubectl delete namespace mtls --ignore-not-found
rm -f peer-authentication.yaml

echo "NOTE: the Istio control plane is left installed."
echo "      Remove it with:  istioctl uninstall --purge -y && kubectl delete namespace istio-system"

echo "[OK] Question 15 cleanup complete"
