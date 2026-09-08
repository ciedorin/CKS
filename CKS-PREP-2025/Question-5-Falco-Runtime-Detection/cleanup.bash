#!/bin/bash
# Cleanup script for Question 5 - Falco runtime detection
set -uo pipefail
echo "Cleaning up Question 5: Falco runtime detection..."

kubectl delete namespace ollama --ignore-not-found

if [[ -f /etc/falco/rules.d/cks-dev-mem.yaml ]]; then
  echo "Removing the custom Falco rule..."
  sudo rm -f /etc/falco/rules.d/cks-dev-mem.yaml
  sudo systemctl restart falco 2>/dev/null \
    || sudo systemctl restart falco-modern-bpf 2>/dev/null \
    || sudo systemctl restart falco-bpf 2>/dev/null \
    || true
fi

echo "[OK] Question 5 cleanup complete"
