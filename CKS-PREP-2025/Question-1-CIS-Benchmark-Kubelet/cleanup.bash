#!/bin/bash
# Cleanup script for Question 1 - CIS Benchmark (kubelet)
set -uo pipefail
echo "Cleaning up Question 1: CIS Benchmark kubelet..."

BACKUP="/opt/cks-backups/kubelet-config.yaml.orig"

if [[ -f "$BACKUP" ]]; then
  echo "Restoring the original kubelet configuration..."
  sudo cp "$BACKUP" /var/lib/kubelet/config.yaml
  sudo rm -f "$BACKUP"
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet
  echo "Waiting for the node to become Ready..."
  for i in $(seq 1 30); do
    kubectl get nodes >/dev/null 2>&1 && break
    sleep 2
  done
else
  echo "No backup found at $BACKUP - leaving the current kubelet configuration in place."
fi

echo "[OK] Question 1 cleanup complete"
