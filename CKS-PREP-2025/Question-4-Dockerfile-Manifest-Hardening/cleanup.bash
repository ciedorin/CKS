#!/bin/bash
# Cleanup script for Question 4 - Dockerfile and manifest hardening
set -uo pipefail
echo "Cleaning up Question 4: Dockerfile / manifest hardening..."

sudo rm -rf /home/candidate/app
sudo rmdir /home/candidate 2>/dev/null || true

echo "[OK] Question 4 cleanup complete"
