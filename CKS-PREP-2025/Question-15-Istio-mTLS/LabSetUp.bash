#!/bin/bash
# Lab setup for Question 15 - Istio mTLS
set -uo pipefail

# Leave ISTIO_VERSION empty to pick up the latest release automatically.
ISTIO_VERSION="${ISTIO_VERSION:-}"
ISTIO_FALLBACK="1.24.2"
READINESS_TIMEOUT="${READINESS_TIMEOUT:-10m}"
ISTIO_RESOLVED_VERSION=""

echo "Preparing Question 15: Istio mTLS"

resolve_version() {
  local ver="$ISTIO_VERSION"
  if [[ -z "$ver" ]]; then
    ver="$(curl -fsSL --max-time 15 https://api.github.com/repos/istio/istio/releases/latest 2>/dev/null \
           | grep -o '"tag_name"[^,]*' | head -1 | sed 's/.*": *"//; s/"//')"
  fi
  [[ -n "$ver" ]] || ver="$ISTIO_FALLBACK"
  echo "$ver"
}

install_istioctl() {
  local ver="$1" arch tmp bin url
  arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
  case "$arch" in amd64|arm64) ;; *) arch="amd64" ;; esac
  tmp="$(mktemp -d)"

  echo "Installing istioctl ${ver} (${arch})..."
  # The istioctl-only archive is a few MB; the full distribution is ~90MB and
  # only the binary is needed, since istioctl carries the charts internally.
  for url in \
    "https://github.com/istio/istio/releases/download/${ver}/istioctl-${ver}-linux-${arch}.tar.gz" \
    "https://github.com/istio/istio/releases/download/${ver}/istio-${ver}-linux-${arch}.tar.gz"
  do
    echo "  trying $url"
    # -f matters: without it curl saves a 404 page and still exits 0
    if curl -fsSL --max-time 300 -o "$tmp/istio.tar.gz" "$url" && gzip -t "$tmp/istio.tar.gz" 2>/dev/null; then
      tar -xzf "$tmp/istio.tar.gz" -C "$tmp"
      bin="$(find "$tmp" -maxdepth 3 -type f -name istioctl | head -1)"
      if [[ -n "$bin" ]]; then
        sudo install -m 0755 "$bin" /usr/local/bin/istioctl
        rm -rf "$tmp"
        echo "  istioctl installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
        return 0
      fi
    fi
  done

  rm -rf "$tmp"
  echo "ERROR: could not download istioctl ${ver}." >&2
  echo "       Check https://github.com/istio/istio/releases and retry with:" >&2
  echo "         ISTIO_VERSION=<version> ./LabSetUp.bash" >&2
  return 1
}

# Pulling the images up front makes the install wait short and, more
# importantly, visible - otherwise istioctl just sits there silently.
prepull_images() {
  local ver="$1" img start
  command -v crictl >/dev/null 2>&1 || return 0
  for img in "docker.io/istio/pilot:${ver}" "docker.io/istio/proxyv2:${ver}"; do
    echo "  pulling $img ..."
    start=$SECONDS
    if sudo crictl pull "$img" >/dev/null 2>&1; then
      echo "    done in $((SECONDS - start))s"
    else
      echo "    WARNING: pull failed - the install will retry it itself"
    fi
  done
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

wait_for_istiod() {
  local deadline=$((SECONDS + $1)) ready
  while (( SECONDS < deadline )); do
    ready="$(kubectl get deployment istiod -n istio-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
    if [[ -n "$ready" && "$ready" -ge 1 ]]; then
      return 0
    fi
    echo "    still waiting (${SECONDS}s elapsed):"
    kubectl get pods -n istio-system --no-headers 2>/dev/null | sed 's/^/      /'
    sleep 15
  done
  return 1
}

# ---------------------------------------------------------------
# 1. istioctl
# ---------------------------------------------------------------
ISTIO_RESOLVED_VERSION="$(resolve_version)"

if ! command -v istioctl >/dev/null 2>&1; then
  install_istioctl "$ISTIO_RESOLVED_VERSION" || { echo "Aborting: istioctl is required." >&2; exit 1; }
else
  echo "istioctl is already installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
  ISTIO_RESOLVED_VERSION="$(istioctl version --remote=false 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -n "$ISTIO_RESOLVED_VERSION" ]] || ISTIO_RESOLVED_VERSION="$ISTIO_FALLBACK"
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
  echo "Pre-pulling the Istio images (the slowest step, a few minutes on a lab node)..."
  prepull_images "$ISTIO_RESOLVED_VERSION"

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
    echo "Common causes: istiod Pending (resources or taints), or ImagePullBackOff." >&2
    echo "Remove a half finished install with:  istioctl uninstall --purge -y" >&2
    exit 1
  fi
fi

echo "Waiting for istiod to be Ready..."
if ! wait_for_istiod 300; then
  echo "ERROR: istiod is not Ready." >&2
  istio_diagnostics
  exit 1
fi
echo "  istiod is Ready."

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
