#!/bin/bash
# Cleanup script for Question 9 - Ingress with TLS
set -uo pipefail
echo "Cleaning up Question 9: Ingress with TLS..."

kubectl delete ingress web -n prod --ignore-not-found
kubectl delete namespace prod --ignore-not-found
rm -f ingress-web.yaml

# Remove the /etc/hosts entry that the manual verification may have added
sudo sed -i '/web.k8s.local/d' /etc/hosts 2>/dev/null || true

echo "NOTE: the ingress-nginx controller is left installed."
echo "      Remove it with:"
echo "      kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/baremetal/deploy.yaml"

echo "[OK] Question 9 cleanup complete"
