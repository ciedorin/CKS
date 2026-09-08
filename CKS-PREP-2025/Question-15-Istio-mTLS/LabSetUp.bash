#!/bin/bash
set -e

ISTIO_VERSION="${ISTIO_VERSION:-1.23.2}"

echo "Preparing Question 15: Istio mTLS"

# ---------------------------------------------------------------
# 1. istioctl
# ---------------------------------------------------------------
if ! command -v istioctl >/dev/null 2>&1; then
  echo "Installing istioctl $ISTIO_VERSION ..."
  cd /opt
  sudo curl -sSL "https://github.com/istio-io/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" -o istio.tar.gz \
    || sudo curl -sSL "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux-amd64.tar.gz" -o istio.tar.gz
  sudo tar -xzf istio.tar.gz
  sudo cp "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/istioctl
  sudo chmod +x /usr/local/bin/istioctl
  sudo rm -f istio.tar.gz
  cd - >/dev/null
fi
istioctl version --remote=false

# ---------------------------------------------------------------
# 2. The Istio control plane
# ---------------------------------------------------------------
if ! kubectl get namespace istio-system >/dev/null 2>&1; then
  echo "Installing the Istio control plane (minimal profile)..."
  istioctl install --set profile=minimal -y
else
  echo "Namespace istio-system already exists - skipping the Istio install."
fi

echo "Waiting for istiod..."
kubectl wait --namespace istio-system \
  --for=condition=Ready pod --selector=app=istiod --timeout=300s || true

# ---------------------------------------------------------------
# 3. The workloads - deliberately WITHOUT sidecar injection
# ---------------------------------------------------------------
echo "Creating namespace mtls (no injection label on purpose)..."
kubectl create namespace mtls --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mtls istio-injection- --overwrite >/dev/null 2>&1 || true

echo "Deploying the workloads..."
kubectl apply -n mtls -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: mtls
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: mtls
spec:
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: mtls
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: mtls
spec:
  selector:
    app: backend
  ports:
  - name: http
    port: 80
    targetPort: 80
EOF

kubectl wait --for=condition=Available --timeout=180s deployment -n mtls --all || true

echo ""
echo "Pods and their container counts (1/1 means no sidecar):"
kubectl get pods -n mtls

echo ""
echo "[OK] Question 15 lab setup complete."
echo "   - Istio control plane in namespace istio-system"
echo "   - Namespace mtls with Deployments frontend and backend (no sidecars yet)"
