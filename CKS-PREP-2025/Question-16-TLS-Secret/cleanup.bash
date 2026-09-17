#!/bin/bash
# Cleanup script for Question 16 - TLS Secret
set -uo pipefail
echo "Cleaning up Question 16: TLS Secret..."

kubectl delete deployment clever-cactus -n clever-cactus --ignore-not-found
kubectl delete secret clever-cactus -n clever-cactus --ignore-not-found
kubectl delete namespace clever-cactus --ignore-not-found

echo "Removing the certificate files..."
sudo rm -rf /opt/course/16
sudo rmdir /opt/course 2>/dev/null || true
rm -f /tmp/cks-q16.key

echo "[OK] Question 16 cleanup complete"
