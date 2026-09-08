#!/bin/bash
# Cleanup script for Question 12 - SBOM
set -uo pipefail
echo "Cleaning up Question 12: SBOM..."

kubectl delete deployment alpine -n alpine --ignore-not-found
kubectl delete namespace alpine --ignore-not-found

echo "Removing the image archives and the generated SBOM..."
sudo rm -rf /opt/course/12
sudo rmdir /opt/course 2>/dev/null || true

echo "[OK] Question 12 cleanup complete"
