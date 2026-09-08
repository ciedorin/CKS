#!/bin/bash
# Cleanup script for Question 11 - Node upgrade
set -uo pipefail
echo "Cleaning up Question 11: Node upgrade..."

echo "Nothing to remove - this question only changes node versions."
echo "Making sure no node was left cordoned..."
for n in $(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}'); do
  kubectl uncordon "$n" >/dev/null 2>&1 || true
done

kubectl get nodes 2>/dev/null

echo "[OK] Question 11 cleanup complete"
