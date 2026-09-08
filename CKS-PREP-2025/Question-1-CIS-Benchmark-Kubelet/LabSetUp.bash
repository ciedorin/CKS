#!/bin/bash
set -e

KUBELET_CONFIG="/var/lib/kubelet/config.yaml"
BACKUP_DIR="/opt/cks-backups"
BACKUP="$BACKUP_DIR/kubelet-config.yaml.orig"

echo "Preparing Question 1: CIS Benchmark - kubelet"

if [[ ! -f "$KUBELET_CONFIG" ]]; then
  echo "ERROR: $KUBELET_CONFIG not found. This lab requires a kubeadm-provisioned node." >&2
  exit 1
fi

echo "Backing up the original kubelet configuration to $BACKUP ..."
sudo mkdir -p "$BACKUP_DIR"
[[ -f "$BACKUP" ]] || sudo cp "$KUBELET_CONFIG" "$BACKUP"

echo "Introducing CIS Benchmark violations into $KUBELET_CONFIG ..."
sudo python3 - <<'PY'
import re

path = "/var/lib/kubelet/config.yaml"
with open(path) as f:
    s = f.read()

# CIS 4.2.1 - anonymous auth must be disabled -> enable it
s = re.sub(r"(anonymous:\s*\n\s*enabled:\s*)\w+", r"\1true", s)

# CIS 4.2.2 - authorization mode must be Webhook -> set AlwaysAllow
s = re.sub(r"(authorization:\s*\n\s*mode:\s*)\w+", r"\1AlwaysAllow", s)

# CIS 4.2.4 - read only port must be 0 -> expose 10255
if re.search(r"^readOnlyPort:", s, re.M):
    s = re.sub(r"^readOnlyPort:.*$", "readOnlyPort: 10255", s, flags=re.M)
else:
    s = s.rstrip("\n") + "\nreadOnlyPort: 10255\n"

# CIS 4.2.5 - streaming connection idle timeout must not be 0 -> set 0
if re.search(r"^streamingConnectionIdleTimeout:", s, re.M):
    s = re.sub(r"^streamingConnectionIdleTimeout:.*$",
               "streamingConnectionIdleTimeout: 0", s, flags=re.M)
else:
    s = s.rstrip("\n") + "\nstreamingConnectionIdleTimeout: 0\n"

with open(path, "w") as f:
    f.write(s)
PY

echo "Restarting kubelet so the broken configuration is live..."
sudo systemctl restart kubelet

echo "Waiting for the node to become Ready again..."
for i in $(seq 1 30); do
  if kubectl get nodes >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo ""
echo "[OK] Question 1 lab setup complete."
echo "   - kubelet config: $KUBELET_CONFIG (contains CIS violations)"
echo "   - original backup: $BACKUP"
