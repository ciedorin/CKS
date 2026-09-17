#!/bin/bash
# Lab setup for Question 1 - CIS Benchmark (kubelet)
#
# NOTE: no "set -e" on purpose - if the kubelet does not come back we roll the
#       configuration back instead of leaving a broken node behind.
set -uo pipefail

KUBELET_CONFIG="/var/lib/kubelet/config.yaml"
BACKUP_DIR="/opt/cks-backups"
BACKUP="$BACKUP_DIR/kubelet-config.yaml.orig"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
KUBE_BENCH_FALLBACK="0.10.7"

echo "Preparing Question 1: CIS Benchmark - kubelet"

if [[ ! -f "$KUBELET_CONFIG" ]]; then
  echo "ERROR: $KUBELET_CONFIG not found. This lab requires a kubeadm-provisioned node." >&2
  exit 1
fi

wait_for_node() {
  local deadline=$((SECONDS + $1))
  while (( SECONDS < deadline )); do
    if systemctl is-active --quiet kubelet && kubectl get nodes >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

show_diagnostics() {
  echo ""
  echo "---------- kubelet service state ----------"
  sudo systemctl status kubelet --no-pager -l 2>/dev/null | head -15
  echo "---------- kubelet journal ----------"
  sudo journalctl -u kubelet --no-pager -n 25 2>/dev/null | tail -25
  echo "-------------------------------------"
}

install_kube_bench() {
  if command -v kube-bench >/dev/null 2>&1; then
    echo "kube-bench is already installed ($(kube-bench version 2>/dev/null | head -1))"
    return 0
  fi

  echo "Installing kube-bench..."
  local arch ver url
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  ver="$(curl -fsSL --max-time 15 https://api.github.com/repos/aquasecurity/kube-bench/releases/latest 2>/dev/null \
         | grep -o '"tag_name"[^,]*' | head -1 | sed 's/.*"v//; s/".*//')"
  [[ -n "$ver" ]] || ver="$KUBE_BENCH_FALLBACK"
  url="https://github.com/aquasecurity/kube-bench/releases/download/v${ver}/kube-bench_${ver}_linux_${arch}.deb"

  echo "  downloading $url"
  if sudo curl -fsSL --max-time 180 -o /tmp/kube-bench.deb "$url"; then
    sudo dpkg -i /tmp/kube-bench.deb >/dev/null 2>&1 || sudo apt-get install -y -f >/dev/null 2>&1
    sudo rm -f /tmp/kube-bench.deb
  fi

  if command -v kube-bench >/dev/null 2>&1; then
    echo "  kube-bench installed: $(kube-bench version 2>/dev/null | head -1)"
  else
    echo "  WARNING: kube-bench could not be installed automatically."
    echo "           Install it by hand from https://github.com/aquasecurity/kube-bench/releases"
    echo "           The question can still be solved by reading the control list."
  fi
}

# ---------------------------------------------------------------
# 0. The node has to be healthy before we break anything
# ---------------------------------------------------------------
echo "Checking that the kubelet is healthy..."
if ! wait_for_node 60; then
  echo "ERROR: the kubelet is not healthy right now." >&2
  echo "       Fix the node first, then re-run this setup." >&2
  if [[ -f "$BACKUP" ]]; then
    echo "       A backup from a previous run exists - restore it with:" >&2
    echo "         sudo cp $BACKUP $KUBELET_CONFIG && sudo systemctl restart kubelet" >&2
  fi
  exit 1
fi

# ---------------------------------------------------------------
# 1. The benchmark tool
# ---------------------------------------------------------------
install_kube_bench

# ---------------------------------------------------------------
# 2. Back up the original configuration
# ---------------------------------------------------------------
echo "Backing up the original kubelet configuration to $BACKUP ..."
sudo mkdir -p "$BACKUP_DIR"
[[ -f "$BACKUP" ]] || sudo cp "$KUBELET_CONFIG" "$BACKUP"

# ---------------------------------------------------------------
# 3. Build the broken configuration in a temp file first
# ---------------------------------------------------------------
TMP_CONFIG="$(mktemp /tmp/kubelet-config.XXXXXX.yaml)"

echo "Introducing CIS Benchmark violations into $KUBELET_CONFIG ..."
sudo python3 - "$KUBELET_CONFIG" "$TMP_CONFIG" <<'PY'
import re, sys

src, dst = sys.argv[1], sys.argv[2]

with open(src) as f:
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

try:
    import yaml
    doc = yaml.safe_load(s)
    assert doc["authentication"]["anonymous"]["enabled"] is True
    assert doc["authorization"]["mode"] == "AlwaysAllow"
    assert doc["readOnlyPort"] == 10255
except ImportError:
    pass
except Exception as exc:
    print("ERROR: the generated kubelet config is not valid: %s" % exc, file=sys.stderr)
    sys.exit(1)

with open(dst, "w") as f:
    f.write(s)
PY

if [[ $? -ne 0 || ! -s "$TMP_CONFIG" ]]; then
  echo "ERROR: could not generate the broken kubelet config - nothing was changed." >&2
  rm -f "$TMP_CONFIG"
  exit 1
fi

sudo cp "$TMP_CONFIG" "$KUBELET_CONFIG"
rm -f "$TMP_CONFIG"

# ---------------------------------------------------------------
# 4. Restart the kubelet, roll back if the node does not come back
# ---------------------------------------------------------------
echo "Restarting kubelet so the broken configuration is live..."
sudo systemctl restart kubelet

echo "Waiting up to ${WAIT_SECONDS}s for the node to become Ready again..."
if ! wait_for_node "$WAIT_SECONDS"; then
  echo ""
  echo "ERROR: the kubelet did not come back after the change." >&2
  show_diagnostics
  echo "Rolling the configuration back to $BACKUP ..." >&2
  sudo cp "$BACKUP" "$KUBELET_CONFIG"
  sudo systemctl restart kubelet
  if wait_for_node 120; then
    echo "The node is healthy again. The lab was NOT set up." >&2
  else
    echo "The kubelet is still down. Restore it by hand:" >&2
    echo "  sudo cp $BACKUP $KUBELET_CONFIG && sudo systemctl restart kubelet" >&2
  fi
  exit 1
fi

echo ""
echo "[OK] Question 1 lab setup complete."
echo "   - kubelet config: $KUBELET_CONFIG (contains CIS violations)"
echo "   - original backup: $BACKUP"
echo ""
echo "   START HERE - run the benchmark and look at the section 4.2 results:"
echo "     sudo kube-bench run --targets node"
