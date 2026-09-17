#!/bin/bash
# Cleanup script for Question 5 - Falco runtime detection
set -uo pipefail
echo "Cleaning up Question 5: Falco runtime detection..."

kubectl delete namespace ollama --ignore-not-found

if [[ -f /etc/falco/rules.d/cks-dev-mem.yaml ]]; then
  echo "Removing the custom Falco rule..."
  sudo rm -f /etc/falco/rules.d/cks-dev-mem.yaml

  FALCO_UNIT=""
  for u in falco-modern-bpf falco-bpf falco-kmod falco; do
    if systemctl is-active --quiet "$u" 2>/dev/null; then
      FALCO_UNIT="$u"
      break
    fi
  done

  if [[ -n "$FALCO_UNIT" ]]; then
    echo "Restarting $FALCO_UNIT ..."
    sudo systemctl restart "$FALCO_UNIT" || true
  fi
fi

echo "NOTE: Falco itself is left installed."
echo "      Remove it with:  sudo apt-get remove -y falco"

echo "[OK] Question 5 cleanup complete"
