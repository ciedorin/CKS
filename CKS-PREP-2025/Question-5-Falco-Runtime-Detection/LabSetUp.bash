#!/bin/bash
set -e

echo "Preparing Question 5: Falco runtime detection"

# ---------------------------------------------------------------
# 1. Falco
# ---------------------------------------------------------------
if ! command -v falco >/dev/null 2>&1; then
  echo "WARNING: falco was not found on this node."
  echo "         Install it before working on this question, for example:"
  echo "           curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg"
  echo "           echo 'deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main' | sudo tee /etc/apt/sources.list.d/falcosecurity.list"
  echo "           sudo apt update && sudo apt install -y falco"
else
  echo "Installing the custom Falco rule that watches for physical memory reads..."
  sudo mkdir -p /etc/falco/rules.d
  sudo tee /etc/falco/rules.d/cks-dev-mem.yaml >/dev/null <<'EOF'
- rule: Read physical memory device
  desc: A process inside a container read the sensitive device /dev/mem
  condition: >
    open_read and container and fd.name = /dev/mem
  output: >
    Sensitive device read detected
    (user=%user.name process=%proc.name command=%proc.cmdline file=%fd.name
     container_id=%container.id container_name=%container.name image=%container.image.repository
     pod=%k8s.pod.name namespace=%k8s.ns.name)
  priority: CRITICAL
  tags: [filesystem, container, mitre_credential_access]
EOF

  echo "Restarting Falco..."
  sudo systemctl restart falco 2>/dev/null \
    || sudo systemctl restart falco-modern-bpf 2>/dev/null \
    || sudo systemctl restart falco-bpf 2>/dev/null \
    || echo "NOTE: could not restart a falco systemd unit - restart it manually."
fi

# ---------------------------------------------------------------
# 2. The ollama application
# ---------------------------------------------------------------
echo "Creating namespace ollama..."
kubectl create namespace ollama --dry-run=client -o yaml | kubectl apply -f -

# pick, at random, which of the three workloads misbehaves
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
kubectl wait --for=condition=Available --timeout=120s deployment -n ollama --all || true

echo ""
echo "[OK] Question 5 lab setup complete."
echo "   - Namespace: ollama"
echo "   - Deployments: ollama-alpha, ollama-beta, ollama-gamma"
echo "   - One of them is reading /dev/mem. Let Falco tell you which one."
