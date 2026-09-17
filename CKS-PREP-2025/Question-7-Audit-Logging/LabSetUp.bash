#!/bin/bash
set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
POLICY_DIR="/etc/kubernetes/policy"
BACKUP_DIR="/opt/cks-backups"
BACKUP="$BACKUP_DIR/kube-apiserver.yaml.q7-orig"

echo "Preparing Question 7: Audit logging"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found. This lab must run on a kubeadm control plane node." >&2
  exit 1
fi

echo "Backing up the original API server manifest to $BACKUP ..."
sudo mkdir -p "$BACKUP_DIR"
[[ -f "$BACKUP" ]] || sudo cp "$MANIFEST" "$BACKUP"

echo "Creating the policy directory and an empty audit policy skeleton..."
sudo mkdir -p "$POLICY_DIR"
sudo tee "$POLICY_DIR/audit-policy.yaml" >/dev/null <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# TODO: the rules are missing - see the question
EOF

echo "Creating namespace webapps with an example Deployment..."
kubectl create namespace webapps --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n webapps -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapps-frontend
  namespace: webapps
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapps-frontend
  template:
    metadata:
      labels:
        app: webapps-frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
EOF

echo "Making sure python3 can parse YAML for the validation script..."
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  sudo apt-get update -q >/dev/null 2>&1 || true
  sudo apt-get install -y python3-yaml >/dev/null 2>&1 || true
fi

echo ""
echo "[OK] Question 7 lab setup complete."
echo "   - Audit policy skeleton: $POLICY_DIR/audit-policy.yaml"
echo "   - Namespace webapps with Deployment webapps-frontend"
echo "   - API server backup: $BACKUP"
