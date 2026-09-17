#!/bin/bash
# Lab setup for Question 15 - Istio mTLS
set -uo pipefail

# Leave ISTIO_VERSION empty to pick up the latest release automatically.
ISTIO_VERSION="${ISTIO_VERSION:-}"
ISTIO_FALLBACK="1.24.2"

echo "Preparing Question 15: Istio mTLS"

install_istioctl() {
  local ver arch url tmp
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  case "$arch" in
    amd64|arm64) ;;
    *) arch="amd64" ;;
  esac

  ver="$ISTIO_VERSION"
  if [[ -z "$ver" ]]; then
    ver="$(curl -fsSL --max-time 15 https://api.github.com/repos/istio/istio/releases/latest 2>/dev/null \
           | grep -o '"tag_name"[^,]*' | head -1 | sed 's/.*": *"//; s/"//')"
  fi
  [[ -n "$ver" ]] || ver="$ISTIO_FALLBACK"

  url="https://github.com/istio/istio/releases/download/${ver}/istio-${ver}-linux-${arch}.tar.gz"
  tmp="$(mktemp -d)"

  echo "Installing istioctl ${ver} (${arch})..."
  echo "  downloading $url"
  # -f matters: without it curl happily saves a 404 page and exits 0
  if ! curl -fsSL --max-time 300 -o "$tmp/istio.tar.gz" "$url"; then
    echo "ERROR: could not download istioctl from $url" >&2
    echo "       Check the available releases at https://github.com/istio/istio/releases" >&2
    echo "       and retry with:  ISTIO_VERSION=<version> ./LabSetUp.bash" >&2
    rm -rf "$tmp"
    return 1
  fi

  if ! gzip -t "$tmp/istio.tar.gz" 2>/dev/null; then
    echo "ERROR: the downloaded file is not a gzip archive - the URL was probably wrong." >&2
    rm -rf "$tmp"
    return 1
  fi

  tar -xzf "$tmp/istio.tar.gz" -C "$tmp"
  if [[ ! -f "$tmp/istio-${ver}/bin/istioctl" ]]; then
    echo "ERROR: istioctl was not found inside the archive." >&2
    rm -rf "$tmp"
    return 1
  fi

  sudo install -m 0755 "$tmp/istio-${ver}/bin/istioctl" /usr/local/bin/istioctl
  rm -rf "$tmp"
  echo "  istioctl installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
}

# ---------------------------------------------------------------
# 1. istioctl
# ---------------------------------------------------------------
if ! command -v istioctl >/dev/null 2>&1; then
  if ! install_istioctl; then
    echo "Aborting: istioctl is required for this question." >&2
    exit 1
  fi
else
  echo "istioctl is already installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
fi

# ---------------------------------------------------------------
# 2. The Istio control plane
# ---------------------------------------------------------------
if ! kubectl get namespace istio-system >/dev/null 2>&1; then
  echo "Installing the Istio control plane (minimal profile)..."
  if ! istioctl install --set profile=minimal -y; then
    echo "ERROR: the Istio installation failed." >&2
    exit 1
  fi
else
  echo "Namespace istio-system already exists - skipping the Istio install."
fi

echo "Waiting for istiod..."
kubectl wait --namespace istio-system \
  --for=condition=Ready pod --selector=app=istiod --timeout=300s

# ---------------------------------------------------------------
# 3. The workloads - deliberately WITHOUT sidecar injection
# ---------------------------------------------------------------
echo "Creating namespace mtls (no injection label on purpose)..."
kubectl create namespace mtls --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mtls istio-injection- --overwrite >/dev/null 2>&1

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

kubectl wait --for=condition=Available --timeout=180s deployment -n mtls --all

echo ""
echo "Pods and their container counts (1/1 means no sidecar):"
kubectl get pods -n mtls

echo ""
echo "[OK] Question 15 lab setup complete."
echo "   - Istio control plane in namespace istio-system"
echo "   - Namespace mtls with Deployments frontend and backend (no sidecars yet)"
