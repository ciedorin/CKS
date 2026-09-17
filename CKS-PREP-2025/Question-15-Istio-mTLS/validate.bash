#!/bin/bash
# Validation script for Question 15 - Istio mTLS
set -uo pipefail

PASS=0
FAIL=0
TOTAL=0

check() {
  local description="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

echo "============================================"
echo " Validating Question 15: Istio mTLS"
echo "============================================"

HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, subprocess, sys

what = sys.argv[1]

def kget(args):
    r = subprocess.run(["kubectl"] + args + ["-o", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return json.loads(r.stdout)

if what == "sidecars":
    pods = kget(["get", "pods", "-n", "mtls"])
    if not pods or not pods.get("items"):
        sys.exit(1)
    running = [p for p in pods["items"]
               if p.get("status", {}).get("phase") == "Running"]
    if not running:
        sys.exit(1)
    for pod in running:
        names = [c["name"] for c in pod["spec"]["containers"]]
        if "istio-proxy" not in names:
            sys.exit(1)
    sys.exit(0)

if what == "strict":
    pas = kget(["get", "peerauthentication", "-n", "mtls"])
    if not pas:
        sys.exit(1)
    for pa in pas.get("items", []):
        spec = pa.get("spec") or {}
        if (spec.get("mtls") or {}).get("mode") == "STRICT":
            sys.exit(0)
    sys.exit(1)

if what == "namespace-wide":
    pas = kget(["get", "peerauthentication", "-n", "mtls"])
    if not pas:
        sys.exit(1)
    for pa in pas.get("items", []):
        spec = pa.get("spec") or {}
        if (spec.get("mtls") or {}).get("mode") != "STRICT":
            continue
        # no selector => applies to every workload in the namespace
        if not spec.get("selector"):
            sys.exit(0)
    sys.exit(1)

if what == "no-port-exception":
    pas = kget(["get", "peerauthentication", "-n", "mtls"])
    if not pas:
        sys.exit(1)
    for pa in pas.get("items", []):
        spec = pa.get("spec") or {}
        for port, cfg in (spec.get("portLevelMtls") or {}).items():
            if (cfg or {}).get("mode") != "STRICT":
                sys.exit(1)
    sys.exit(0)

sys.exit(1)
PY

# 1. Istio is there
check "the Istio control plane is installed (namespace istio-system)" \
  kubectl get namespace istio-system

check "istiod is running" \
  bash -c 'kubectl get pods -n istio-system -l app=istiod --no-headers 2>/dev/null | grep -q Running'

# 2. sidecar injection
check "namespace 'mtls' is labelled for automatic sidecar injection" \
  bash -c 'L=$(kubectl get namespace mtls -o jsonpath="{.metadata.labels.istio-injection}" 2>/dev/null); R=$(kubectl get namespace mtls -o jsonpath="{.metadata.labels.istio\.io/rev}" 2>/dev/null); [[ "$L" == "enabled" || -n "$R" ]]'

check "every running pod in namespace 'mtls' has the istio-proxy sidecar" \
  bash -c "python3 $HELPER sidecars"

check "the frontend and backend deployments are Available" \
  kubectl wait --for=condition=Available --timeout=180s deployment -n mtls --all

# 3. STRICT mTLS
check "a PeerAuthentication exists in namespace 'mtls'" \
  bash -c 'kubectl get peerauthentication -n mtls --no-headers 2>/dev/null | grep -q .'

check "mutual TLS mode is STRICT" \
  bash -c "python3 $HELPER strict"

check "the STRICT policy applies to the whole namespace (no workload selector)" \
  bash -c "python3 $HELPER namespace-wide"

check "no port level exception weakens the STRICT policy" \
  bash -c "python3 $HELPER no-port-exception"

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."

echo ""
echo "============================================"
echo " Manual validation"
echo "============================================"
echo "  kubectl get pods -n mtls                       # every pod 2/2"
echo "  istioctl x describe pod -n mtls <pod-name>     # 'mTLS: STRICT'"

exit $FAIL
