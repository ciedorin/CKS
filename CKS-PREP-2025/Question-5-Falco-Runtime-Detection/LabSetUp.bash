#!/bin/bash
# Lab setup for Question 5 - Falco runtime detection
set -uo pipefail

echo "Preparing Question 5: Falco runtime detection"

FALCO_UNIT=""
FALCO_NODE=""

unit_exists() { systemctl cat "$1" >/dev/null 2>&1; }

find_active_falco_unit() {
  for u in falco-modern-bpf falco-bpf falco-kmod falco; do
    if systemctl is-active --quiet "$u" 2>/dev/null; then echo "$u"; return 0; fi
  done
  echo ""
  return 1
}

install_falco() {
  echo "Falco is not installed - installing it now (this takes a couple of minutes)..."
  sudo apt-get update -q
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends ca-certificates curl gnupg dialog

  curl -fsSL https://falco.org/repo/falcosecurity-packages.asc \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/falco-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/falcosecurity.list >/dev/null

  sudo apt-get update -q
  # FALCO_FRONTEND=noninteractive skips the interactive driver selection dialog
  sudo DEBIAN_FRONTEND=noninteractive FALCO_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends falco

  if command -v falco >/dev/null 2>&1; then
    echo "  Falco installed: $(falco --version 2>/dev/null | head -1)"
    return 0
  fi
  echo "  ERROR: the Falco package could not be installed." >&2
  return 1
}

# Modern packages ship one unit per driver - try them until one actually runs.
start_falco() {
  for u in falco-modern-bpf falco-bpf falco-kmod falco; do
    unit_exists "$u" || continue
    echo "  trying driver unit: $u"
    sudo systemctl enable --now "$u" >/dev/null 2>&1
    sleep 6
    if systemctl is-active --quiet "$u"; then
      FALCO_UNIT="$u"
      echo "  -> $u is running"
      return 0
    fi
    sudo systemctl disable --now "$u" >/dev/null 2>&1
  done
  return 1
}

# ---------------------------------------------------------------
# 1. Falco
# ---------------------------------------------------------------
command -v falco >/dev/null 2>&1 || install_falco

if command -v falco >/dev/null 2>&1; then
  echo "Installing the custom Falco rule that watches for physical memory reads..."
  sudo mkdir -p /etc/falco/rules.d
  # The condition deliberately avoids the open_read macro: that macro requires
  # fd.typechar='f', while /dev/mem is a character device, so the rule could
  # silently never fire. evt.dir is not used either, to keep Falco from warning.
  sudo tee /etc/falco/rules.d/cks-dev-mem.yaml >/dev/null <<'EOF'
- rule: Read physical memory device
  desc: A process inside a container read the sensitive device /dev/mem
  condition: >
    evt.type in (open,openat,openat2) and evt.is_open_read=true
    and container and fd.name=/dev/mem
  output: >
    Sensitive device read detected
    (user=%user.name process=%proc.name command=%proc.cmdline file=%fd.name
     container_id=%container.id container_name=%container.name image=%container.image.repository
     pod=%k8s.pod.name namespace=%k8s.ns.name)
  priority: CRITICAL
  tags: [filesystem, container, mitre_credential_access]
EOF

  FALCO_UNIT="$(find_active_falco_unit)"
  if [[ -n "$FALCO_UNIT" ]]; then
    echo "Restarting $FALCO_UNIT to load the new rule..."
    sudo systemctl restart "$FALCO_UNIT"
  else
    echo "Starting Falco..."
    start_falco
  fi
fi

if [[ -z "$FALCO_UNIT" ]]; then
  echo ""
  echo "WARNING: Falco is not running on this node."
  echo "         Check what exists and start one by hand:"
  echo "           systemctl list-units --all 'falco*'"
  echo "           sudo systemctl start falco-modern-bpf   # or falco-bpf / falco-kmod"
  echo "         Then re-run this setup script."
fi

# ---------------------------------------------------------------
# 2. Where to place the workloads
# ---------------------------------------------------------------
# Falco only sees syscalls on the kernel of the host it runs on. It was just
# installed on THIS node, so the pods have to be scheduled here as well -
# otherwise they land on a worker where nothing is watching and no alert is
# ever produced.
FALCO_NODE="$(hostname)"
if ! kubectl get node "$FALCO_NODE" >/dev/null 2>&1; then
  FALCO_NODE="$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
                -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
fi
if [[ -z "$FALCO_NODE" ]]; then
  FALCO_NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"
fi

if [[ -z "$FALCO_NODE" ]]; then
  echo "ERROR: could not determine which node to pin the workloads to." >&2
  exit 1
fi
echo "Pinning the workloads to the node running Falco: $FALCO_NODE"

# ---------------------------------------------------------------
# 3. The ollama application
# ---------------------------------------------------------------
echo "Creating namespace ollama..."
kubectl create namespace ollama --dry-run=client -o yaml | kubectl apply -f -

NAMES=(alpha beta gamma)
CULPRIT="${NAMES[$((RANDOM % 3))]}"

echo "Creating the application scripts..."
TMPDIR_Q5="$(mktemp -d)"
for n in alpha beta gamma; do
  if [[ "$n" == "$CULPRIT" ]]; then
    cat > "$TMPDIR_Q5/$n.sh" <<'EOF'
#!/bin/sh
# ollama model cache warmer
while true; do
  head -c 64 /dev/mem > /dev/null 2>&1
  sleep 5
done
EOF
  else
    cat > "$TMPDIR_Q5/$n.sh" <<'EOF'
#!/bin/sh
# ollama model cache warmer
while true; do
  head -c 64 /dev/urandom > /dev/null 2>&1
  sleep 5
done
EOF
  fi
done

kubectl create configmap ollama-scripts -n ollama \
  --from-file="$TMPDIR_Q5/alpha.sh" \
  --from-file="$TMPDIR_Q5/beta.sh" \
  --from-file="$TMPDIR_Q5/gamma.sh" \
  --dry-run=client -o yaml | kubectl apply -f -
rm -rf "$TMPDIR_Q5"

echo "Deploying the three ollama workloads..."
for n in alpha beta gamma; do
  kubectl apply -n ollama -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama-$n
  namespace: ollama
  labels:
    app: ollama
    component: $n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
      component: $n
  template:
    metadata:
      labels:
        app: ollama
        component: $n
    spec:
      nodeSelector:
        kubernetes.io/hostname: $FALCO_NODE
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: ollama
        image: busybox:1.36
        command: ["/bin/sh", "/scripts/$n.sh"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: scripts
          mountPath: /scripts
      volumes:
      - name: scripts
        configMap:
          name: ollama-scripts
          defaultMode: 0755
EOF
done

echo "Waiting for the pods to start..."
kubectl wait --for=condition=Available --timeout=120s deployment -n ollama --all

echo ""
echo "Pod placement (all three must sit on $FALCO_NODE):"
kubectl get pods -n ollama -o wide

# ---------------------------------------------------------------
# 4. Self test - is Falco actually alerting?
# ---------------------------------------------------------------
if [[ -n "$FALCO_UNIT" ]]; then
  echo ""
  echo "Self test: waiting up to 60s for the first Falco alert..."
  ALERTS=0
  for i in $(seq 1 12); do
    ALERTS=$(sudo journalctl -u "$FALCO_UNIT" --since "-5 min" --no-pager 2>/dev/null | grep -c "/dev/mem")
    [[ "$ALERTS" -gt 0 ]] && break
    sleep 5
  done
  if [[ "$ALERTS" -gt 0 ]]; then
    echo "  OK - Falco is alerting ($ALERTS events). The alert content is hidden on purpose."
  else
    echo "  WARNING - no alert seen yet. Check with:"
    echo "    sudo journalctl -u $FALCO_UNIT --no-pager -n 30"
    echo "    sudo falco -L 2>/dev/null | grep -i 'physical memory'"
    echo "    kubectl get pods -n ollama -o wide      # must be on $FALCO_NODE"
  fi
fi

echo ""
echo "[OK] Question 5 lab setup complete."
echo "   - Namespace: ollama"
echo "   - Deployments: ollama-alpha, ollama-beta, ollama-gamma (pinned to $FALCO_NODE)"
if [[ -n "$FALCO_UNIT" ]]; then
  echo "   - Falco systemd unit: $FALCO_UNIT"
  echo "     Watch alerts with:  sudo journalctl -fu $FALCO_UNIT"
else
  echo "   - Falco is NOT running - see the warning above."
fi
echo "   - One workload is reading /dev/mem. Let Falco tell you which one."
