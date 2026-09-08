#!/bin/bash
# Cleanup script for Question 3 - ImagePolicyWebhook
set -uo pipefail
echo "Cleaning up Question 3: ImagePolicyWebhook..."

BACKUP="/opt/cks-backups/kube-apiserver.yaml.q3-orig"

if [[ -f "$BACKUP" ]]; then
  echo "Restoring the original kube-apiserver manifest..."
  sudo cp "$BACKUP" /etc/kubernetes/manifests/kube-apiserver.yaml
  sudo rm -f "$BACKUP"
  echo "Waiting for the API server to come back..."
  for i in $(seq 1 60); do
    kubectl get --raw /healthz >/dev/null 2>&1 && break
    sleep 3
  done
else
  echo "No backup found at $BACKUP - leaving the current manifest in place."
fi

echo "Removing the admission configuration directory..."
sudo rm -rf /etc/kubernetes/admission

kubectl delete pod cks-q3-probe --ignore-not-found

echo "[OK] Question 3 cleanup complete"
