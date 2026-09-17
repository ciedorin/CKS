#!/bin/bash
# Cleanup script for Question 2 - API server hardening
set -uo pipefail
echo "Cleaning up Question 2: API server hardening..."

BACKUP="/opt/cks-backups/kube-apiserver.yaml.orig"

kubectl delete clusterrolebinding system:anonymous --ignore-not-found

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

echo "[OK] Question 2 cleanup complete"
