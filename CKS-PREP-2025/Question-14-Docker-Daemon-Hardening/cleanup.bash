#!/bin/bash
# Cleanup script for Question 14 - Docker daemon hardening
set -uo pipefail
echo "Cleaning up Question 14: Docker daemon hardening..."

BACKUP="/opt/cks-backups/docker-daemon.json.orig"

echo "Removing the lab systemd drop-in..."
sudo rm -f /etc/systemd/system/docker.service.d/cks-override.conf
sudo rmdir /etc/systemd/system/docker.service.d 2>/dev/null || true

if [[ -f "$BACKUP" ]]; then
  echo "Restoring the original /etc/docker/daemon.json ..."
  sudo cp "$BACKUP" /etc/docker/daemon.json
  sudo rm -f "$BACKUP"
else
  echo "Removing the lab /etc/docker/daemon.json ..."
  sudo rm -f /etc/docker/daemon.json
fi

echo "Removing the user developer..."
sudo gpasswd -d developer docker >/dev/null 2>&1 || true
sudo userdel -r developer >/dev/null 2>&1 || true

sudo systemctl daemon-reload
sudo systemctl restart docker >/dev/null 2>&1 || true

echo "[OK] Question 14 cleanup complete"
