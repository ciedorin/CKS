#!/bin/bash
# Lab setup for Question 15 - Istio mTLS
set -uo pipefail

# Leave ISTIO_VERSION empty to pick up the latest release automatically.
ISTIO_VERSION="${ISTIO_VERSION:-}"
ISTIO_FALLBACK="1.24.2"
READINESS_TIMEOUT="${READINESS_TIMEOUT:-5m}"

echo "Preparing Question 15: Istio mTLS"

install_istioctl() {
  local ver arch url tmp
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  case "$arch" in amd64|arm64) ;; *) arch="amd64" ;; esac

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
    echo "       Retry with:  ISTIO_VERSION=<version> ./LabSetUp.bash" >&2
    rm -rf "$tmp"; return 1
  fi
  if ! gzip -t "$tmp/istio.tar.gz" 2>/dev/null; then
    echo "ERROR: the downloaded file is not a gzip archive - the URL was wrong." >&2
    rm -rf "$tmp"; return 1
  fi
  tar -xzf "$tmp/istio.tar.gz" -C "$tmp"
  if [[ ! -f "$tmp/istio-${ver}/bin/istioctl" ]]; then
    echo "ERROR: istioctl was not found inside the archive." >&2
    rm -rf "$tmp"; return 1
  fi
  sudo install -m 0755 "$tmp/istio-${ver}/bin/istioctl" /usr/local/bin/istioctl
  rm -rf "$tmp"
  echo "  istioctl installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
}

check_schedulable() {
  local total tainted
  total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  tainted=$(kubectl get nodes -o jsonpath='{range .items[*]}{.spec.taints[?(@.effect=="NoSchedule")].key}{"\n"}{end}' 2>/dev/null \
            | grep -c "node-role.kubernetes.io/control-plane")
  if [[ "$total" -gt 0 && "$total" -eq "$tainted" ]]; then
    echo ""
    echo "WARNING: every node carries the control-plane NoSchedule taint, so istiod"
    echo "         cannot be scheduled. Remove it with:"
    echo "           kubectl taint nodes --all node-role.kubernetes.io/control-plane-"
    return 1
  fi
  return 0
}

istio_diagnostics() {
  echo ""
  echo "---------- istio-system pods ----------"
  kubectl get pods -n istio-system -o wide 2>/dev/null
  echo "---------- istiod pod details ----------"
  kubectl describe pod -n istio-system -l app=istiod 2>/dev/null | tail -25
  echo "---------- recent events ----------"
  kubectl get events -n istio-system --sort-by=.lastTimestamp 2>/dev/null | tail -12
  echo "---------- node allocation ----------"
  kubectl describe nodes 2>/dev/null | grep -A7 "Allocated resources" | head -24
  echo "----------------------------------------"
}

# ---------------------------------------------------------------
# 1. istioctl
# ---------------------------------------------------------------
if ! command -v istioctl >/dev/null 2>&1; then
  install_istioctl || { echo "Aborting: istioctl is required." >&2; exit 1; }
else
  echo "istioctl is already installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
fi

# ---------------------------------------------------------------
# 2. The Istio control plane
# ---------------------------------------------------------------
check_schedulable || true

if kubectl get deployment istiod -n istio-system >/dev/null 2>&1; then
  if kubectl wait --for=condition=Available --timeout=30s deployment/istiod -n istio-system >/dev/null 2>&1; then
    echo "istiod is already installed and healthy - skipping the control plane install."
  else
    echo "ERROR: an existing istiod install was found, but it is not healthy." >&2
    istio_diagnostics
    echo "This is usually a half finished install left by an interrupted run." >&2
    echo "Clean it up and re-run this setup:" >&2
    echo "  istioctl uninstall --purge -y" >&2
    echo "  kubectl delete namespace istio-system --ignore-not-found" >&2
    exit 1
  fi
else
  echo "Installing the Istio control plane (minimal profile)..."
  echo "  istiod defaults to 500m CPU / 2Gi memory requests, which does not fit on a"
  echo "  small lab node - installing with reduced requests."
  if ! istioctl install -y \
        --set profile=minimal \
        --set values.pilot.resources.requests.cpu=100m \
        --set values.pilot.resources.requests.memory=256Mi \
        --set values.global.proxy.resources.requests.cpu=10m \
        --set values.global.proxy.resources.requests.memory=64Mi \
        --readiness-timeout "$READINESS_TIMEOUT"; then
    echo ""
    echo "ERROR: the Istio control plane did not become ready." >&2
    istio_diagnostics
    echo "Common causes:" >&2
    echo "  - istiod Pending: not enough CPU/memory, or every node is tainted" >&2
    echo "  - ImagePullBackOff: the node cannot reach docker.io" >&2
    echo "Remove a half finished install with:  istioctl uninstall --purge -y" >&2
    exit 1
  fi
fi

echo "Waiting for istiod to be Ready..."
if ! kubectl wait --namespace istio-system \
      --for=condition=Ready pod --selector=app=istiod --timeout=300s; then
  echo "ERROR: istiod is not Ready." >&2
  istio_diagnostics
  exit 1
fi

# ---------------------------------------------------------------
# 3. The workloads - deliberately WITHOUT sidecar injection
# ---------------------------------------------------------------
echo "Creating namespace mtls (no injection label on purpose)..."
kubectl create namespace mtls --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace mtls istio-injection- --overwrite >/dev/null 2>&1

echo "Deploying the workloads..."
for app in frontend backend; do
  kubectl apply -n mtls -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app
  namespace: mtls
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $app
  template:
    metadata:
      labels:
        app: $app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
---
apiVersion: v1
kind: Service
metadata:
  name: $app
  namespace: mtls
spec:
  selector:
    app: $app
  ports:
  - name: http
    port: 80
    targetPort: 80
EOF
done

if ! kubectl wait --for=condition=Available --timeout=180s deployment -n mtls --all; then
  echo "WARNING: the workloads are not Available yet."
  kubectl get pods -n mtls
fi

echo ""
echo "Pods and their container counts (1/1 means no sidecar):"
kubectl get pods -n mtls

echo ""
echo "[OK] Question 15 lab setup complete."
echo "   - Istio control plane in namespace istio-system"
echo "   - Namespace mtls with Deployments frontend and backend (no sidecars yet)"
