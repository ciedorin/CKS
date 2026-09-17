#!/bin/bash
# Validation script for Question 10 - ServiceAccount token
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
echo " Validating Question 10: ServiceAccount token"
echo "============================================"

MOUNT_PATH="/var/run/secrets/stats-monitor"

HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, subprocess, sys

MOUNT_PATH = "/var/run/secrets/stats-monitor"
what = sys.argv[1]

r = subprocess.run(["kubectl", "get", "deployment", "stats-monitor", "-n", "monitoring", "-o", "json"],
                   capture_output=True, text=True)
if r.returncode != 0:
    sys.exit(1)

spec = json.loads(r.stdout)["spec"]["template"]["spec"]
volumes = spec.get("volumes") or []
containers = spec.get("containers") or []

def token_volumes():
    names = []
    for vol in volumes:
        projected = vol.get("projected") or {}
        for source in projected.get("sources") or []:
            if "serviceAccountToken" in source:
                names.append(vol["name"])
                break
    return names

if what == "sa":
    sys.exit(0 if spec.get("serviceAccountName") == "stats-monitor-sa" else 1)

if what == "projected-volume":
    sys.exit(0 if token_volumes() else 1)

if what == "mounted":
    names = token_volumes()
    for c in containers:
        for m in c.get("volumeMounts") or []:
            if m.get("name") in names and m.get("mountPath", "").rstrip("/") == MOUNT_PATH:
                sys.exit(0)
    sys.exit(1)

if what == "no-secret-volume":
    # a long lived Secret volume is not what was asked for
    for vol in volumes:
        if (vol.get("secret") or {}).get("secretName"):
            sys.exit(1)
    sys.exit(0)

if what == "automount-not-reenabled":
    sys.exit(1 if spec.get("automountServiceAccountToken") is True else 0)

sys.exit(1)
PY

# 1. the ServiceAccount no longer auto mounts credentials
check "ServiceAccount 'stats-monitor-sa' exists in namespace 'monitoring'" \
  kubectl get serviceaccount stats-monitor-sa -n monitoring

check "automountServiceAccountToken is false on the ServiceAccount" \
  bash -c 'V=$(kubectl get sa stats-monitor-sa -n monitoring -o jsonpath="{.automountServiceAccountToken}" 2>/dev/null); [[ "$V" == "false" ]]'

# 2. the Deployment mounts the token explicitly
check "Deployment 'stats-monitor' exists in namespace 'monitoring'" \
  kubectl get deployment stats-monitor -n monitoring

check "the Deployment still uses the ServiceAccount stats-monitor-sa" \
  bash -c "python3 $HELPER sa"

check "the pod template has a projected serviceAccountToken volume" \
  bash -c "python3 $HELPER projected-volume"

check "the token volume is mounted at $MOUNT_PATH" \
  bash -c "python3 $HELPER mounted"

check "no long lived Secret volume was used instead" \
  bash -c "python3 $HELPER no-secret-volume"

check "the automount was not re-enabled on the pod template" \
  bash -c "python3 $HELPER automount-not-reenabled"

# 3. the result at runtime
check "the Deployment is Available after the change" \
  kubectl wait --for=condition=Available --timeout=120s deployment/stats-monitor -n monitoring

check "the token file is readable at $MOUNT_PATH/token inside the pod" \
  bash -c 'kubectl exec -n monitoring deploy/stats-monitor -- test -s /var/run/secrets/stats-monitor/token'

check "the default credentials path is NOT mounted any more" \
  bash -c 'kubectl exec -n monitoring deploy/stats-monitor -- test -e /var/run/secrets/kubernetes.io/serviceaccount >/dev/null 2>&1 && exit 1 || exit 0'

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
