#!/bin/bash
# Cleanup script for Question 7 - Audit logging
set -uo pipefail
echo "Cleaning up Question 7: Audit logging..."

BACKUP="/opt/cks-backups/kube-apiserver.yaml.q7-orig"

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

kubectl delete namespace webapps --ignore-not-found

echo "Removing the audit policy and log files..."
sudo rm -rf /etc/kubernetes/policy
sudo rm -f /etc/kubernetes/audit.logs.txt*

echo "[OK] Question 7 cleanup complete"
