#!/bin/bash
# Validation script for Question 2 - API server hardening
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
echo " Validating Question 2: API server hardening"
echo "============================================"

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"

# 1. anonymous authentication is disabled
check "kube-apiserver has --anonymous-auth=false" \
  bash -c 'sudo grep -qE "^[[:space:]]*-[[:space:]]*--anonymous-auth=false" /etc/kubernetes/manifests/kube-apiserver.yaml'

# 2. authorization mode is exactly Node,RBAC
check "kube-apiserver --authorization-mode is Node,RBAC" \
  bash -c 'MODE=$(sudo grep -oP "(?<=--authorization-mode=)\S+" /etc/kubernetes/manifests/kube-apiserver.yaml | head -1); [[ "$MODE" == "Node,RBAC" || "$MODE" == "RBAC,Node" ]]'

# 3. NodeRestriction admission controller is enabled
check "NodeRestriction admission plugin is enabled" \
  bash -c 'sudo grep -oP "(?<=--enable-admission-plugins=)\S+" /etc/kubernetes/manifests/kube-apiserver.yaml | head -1 | grep -q "NodeRestriction"'

# 4. the previously enabled plugins were not dropped
check "existing admission plugins were kept (NamespaceLifecycle still enabled)" \
  bash -c 'sudo grep -oP "(?<=--enable-admission-plugins=)\S+" /etc/kubernetes/manifests/kube-apiserver.yaml | head -1 | grep -q "NamespaceLifecycle"'

# 5. the API server is healthy again
check "API server is healthy" \
  bash -c 'for i in $(seq 1 20); do kubectl get --raw /healthz >/dev/null 2>&1 && exit 0; sleep 3; done; exit 1'

# 6. the ClusterRoleBinding system:anonymous is gone
check "ClusterRoleBinding system:anonymous no longer exists" \
  bash -c 'kubectl get clusterrolebinding system:anonymous >/dev/null 2>&1 && exit 1 || exit 0'

# 7. anonymous API access is rejected with 401
check "anonymous request to the API returns 401" \
  bash -c 'CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 10 https://127.0.0.1:6443/api/v1/nodes); [[ "$CODE" == "401" ]]'

# 8. all nodes are still Ready
check "all nodes are Ready" \
  bash -c 'NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk "{print \$2}" | grep -cv "^Ready$"); [[ "$NOT_READY" -eq 0 ]]'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
