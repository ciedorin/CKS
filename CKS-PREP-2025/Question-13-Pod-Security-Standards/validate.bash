#!/bin/bash
# Validation script for Question 13 - Pod Security Standards
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
echo " Validating Question 13: Pod Security Standards"
echo "============================================"

HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, subprocess, sys

what = sys.argv[1]

r = subprocess.run(["kubectl", "get", "deployment", "confidential-app",
                    "-n", "confidential", "-o", "json"],
                   capture_output=True, text=True)
if r.returncode != 0:
    sys.exit(1)

spec = json.loads(r.stdout)["spec"]["template"]["spec"]
pod_sc = spec.get("securityContext") or {}
containers = (spec.get("containers") or []) + (spec.get("initContainers") or [])
if not containers:
    sys.exit(1)

def csc(c):
    return c.get("securityContext") or {}

if what == "runAsNonRoot":
    ok = all(csc(c).get("runAsNonRoot", pod_sc.get("runAsNonRoot")) is True
             for c in containers)
    sys.exit(0 if ok else 1)

if what == "runAsUser":
    # runAsNonRoot: true only works if the uid is not 0
    for c in containers:
        uid = csc(c).get("runAsUser", pod_sc.get("runAsUser"))
        if uid == 0:
            sys.exit(1)
    sys.exit(0)

if what == "allowPrivilegeEscalation":
    ok = all(csc(c).get("allowPrivilegeEscalation") is False for c in containers)
    sys.exit(0 if ok else 1)

if what == "capabilities":
    for c in containers:
        drop = ((csc(c).get("capabilities") or {}).get("drop") or [])
        if "ALL" not in [str(d).upper() for d in drop]:
            sys.exit(1)
    sys.exit(0)

if what == "seccomp":
    for c in containers:
        prof = csc(c).get("seccompProfile") or pod_sc.get("seccompProfile") or {}
        if prof.get("type") not in ("RuntimeDefault", "Localhost"):
            sys.exit(1)
    sys.exit(0)

if what == "no-privileged":
    for c in containers:
        if csc(c).get("privileged") is True:
            sys.exit(1)
        if spec.get("hostNetwork") or spec.get("hostPID") or spec.get("hostIPC"):
            sys.exit(1)
    sys.exit(0)

sys.exit(1)
PY

# 1. the namespace still enforces restricted
check "namespace 'confidential' still enforces the restricted standard" \
  bash -c 'V=$(kubectl get namespace confidential -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/enforce}" 2>/dev/null); [[ "$V" == "restricted" ]]'

# 2. the deployment exists
check "Deployment 'confidential-app' exists in namespace 'confidential'" \
  kubectl get deployment confidential-app -n confidential

# 3. the restricted requirements
check "every container sets runAsNonRoot: true" \
  bash -c "python3 $HELPER runAsNonRoot"

check "no container runs with uid 0" \
  bash -c "python3 $HELPER runAsUser"

check "every container sets allowPrivilegeEscalation: false" \
  bash -c "python3 $HELPER allowPrivilegeEscalation"

check "every container drops ALL capabilities" \
  bash -c "python3 $HELPER capabilities"

check "seccompProfile is RuntimeDefault (or Localhost)" \
  bash -c "python3 $HELPER seccomp"

check "no privileged container and no host namespaces are used" \
  bash -c "python3 $HELPER no-privileged"

# 4. the pods really run now
check "the Deployment is Available" \
  kubectl wait --for=condition=Available --timeout=120s deployment/confidential-app -n confidential

check "at least one pod is Running in namespace 'confidential'" \
  bash -c 'kubectl get pods -n confidential --no-headers 2>/dev/null | grep -q Running'

check "the pod template is accepted by Pod Security Admission (server dry-run)" \
  bash -c 'kubectl get deployment confidential-app -n confidential -o yaml | kubectl apply --dry-run=server -f - >/dev/null 2>&1'

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
