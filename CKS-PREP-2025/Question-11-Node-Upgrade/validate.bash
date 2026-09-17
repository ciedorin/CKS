#!/bin/bash
# Validation script for Question 11 - Node upgrade
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
echo " Validating Question 11: Node upgrade"
echo "============================================"

echo ""
kubectl get nodes -o wide 2>/dev/null
echo ""

# 1. the cluster has more than one node
check "the cluster has at least one worker node" \
  bash -c 'N=$(kubectl get nodes --no-headers 2>/dev/null | wc -l); [[ "$N" -ge 2 ]]'

# 2. every node runs the control plane version
check "every node runs the same kubelet version as the control plane" \
  bash -c 'CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath="{.items[0].status.nodeInfo.kubeletVersion}" 2>/dev/null); [[ -n "$CP" ]] || exit 1; U=$(kubectl get nodes -o jsonpath="{range .items[*]}{.status.nodeInfo.kubeletVersion}{\"\n\"}{end}" 2>/dev/null | sort -u | wc -l); [[ "$U" -eq 1 ]]'

# 3. no node lags behind on an older minor version
check "no node reports an older minor version than the control plane" \
  bash -c 'CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath="{.items[0].status.nodeInfo.kubeletVersion}" 2>/dev/null | tr -d "v"); CPM=$(echo "$CP" | cut -d. -f2); for V in $(kubectl get nodes -o jsonpath="{range .items[*]}{.status.nodeInfo.kubeletVersion}{\"\n\"}{end}" 2>/dev/null | tr -d "v"); do M=$(echo "$V" | cut -d. -f2); [[ "$M" -lt "$CPM" ]] && exit 1; done; exit 0'

# 4. all nodes are Ready
check "all nodes are Ready" \
  bash -c 'NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk "{print \$2}" | grep -cv "^Ready$"); [[ "$NOT_READY" -eq 0 ]]'

# 5. no node is left cordoned
check "no node is left cordoned (SchedulingDisabled)" \
  bash -c 'kubectl get nodes --no-headers 2>/dev/null | grep -q "SchedulingDisabled" && exit 1 || exit 0'

check "no node has spec.unschedulable set" \
  bash -c 'U=$(kubectl get nodes -o jsonpath="{range .items[*]}{.spec.unschedulable}{\"\n\"}{end}" 2>/dev/null | grep -c "true"); [[ "$U" -eq 0 ]]'

# 6. the control plane is still healthy
check "the API server is healthy" \
  bash -c 'kubectl get --raw /healthz >/dev/null 2>&1'

check "no kube-system pod is stuck in a bad state" \
  bash -c 'kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -vE "Running|Completed" | grep -q . && exit 1 || exit 0'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
