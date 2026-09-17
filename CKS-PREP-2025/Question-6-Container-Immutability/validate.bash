#!/bin/bash
# Validation script for Question 6 - Container immutability
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
echo " Validating Question 6: Container immutability"
echo "============================================"

# helper: inspect the pod template with python3 (stdlib json only)
HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, subprocess, sys

what = sys.argv[1]

raw = subprocess.run(
    ["kubectl", "get", "deployment", "lamp-deployment", "-n", "lamp", "-o", "json"],
    capture_output=True, text=True)
if raw.returncode != 0:
    sys.exit(1)

spec = json.loads(raw.stdout)["spec"]["template"]["spec"]
pod_sc = spec.get("securityContext") or {}
containers = spec.get("containers") or []
if not containers:
    sys.exit(1)

def field(c, name):
    sc = c.get("securityContext") or {}
    if name in sc:
        return sc[name]
    return pod_sc.get(name)

if what == "runAsUser":
    sys.exit(0 if all(field(c, "runAsUser") == 20004 for c in containers) else 1)

if what == "readOnlyRootFilesystem":
    # container level only field
    sys.exit(0 if all((c.get("securityContext") or {}).get("readOnlyRootFilesystem") is True
                      for c in containers) else 1)

if what == "allowPrivilegeEscalation":
    sys.exit(0 if all((c.get("securityContext") or {}).get("allowPrivilegeEscalation") is False
                      for c in containers) else 1)

if what == "containers":
    sys.exit(0 if len(containers) == 2 else 1)

sys.exit(1)
PY

# 1. the deployment still exists
check "Deployment 'lamp-deployment' exists in namespace 'lamp'" \
  kubectl get deployment lamp-deployment -n lamp

# 2. both containers are still there
check "the Deployment still has both containers (apache, mysql)" \
  bash -c "python3 $HELPER containers"

# 3. runAsUser 20004 on every container (pod level counts too)
check "every container runs with user ID 20004" \
  bash -c "python3 $HELPER runAsUser"

# 4. read only root filesystem on every container
check "every container has a read-only root filesystem" \
  bash -c "python3 $HELPER readOnlyRootFilesystem"

# 5. privilege escalation forbidden on every container
check "every container forbids privilege escalation" \
  bash -c "python3 $HELPER allowPrivilegeEscalation"

# 6. the deployment rolled out and the pods are running
check "the Deployment is Available after the change" \
  kubectl wait --for=condition=Available --timeout=90s deployment/lamp-deployment -n lamp

check "pods in namespace 'lamp' are Running" \
  bash -c 'kubectl get pods -n lamp --no-headers 2>/dev/null | grep -q Running'

# 7. the running pod really has uid 20004
check "the running container reports uid=20004" \
  bash -c 'POD=$(kubectl get pods -n lamp -l app=lamp -o jsonpath="{.items[0].metadata.name}" 2>/dev/null); kubectl exec -n lamp "$POD" -c apache -- id -u 2>/dev/null | grep -qx "20004"'

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
