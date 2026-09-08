#!/bin/bash
# Validation script for Question 1 - CIS Benchmark (kubelet)
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
echo " Validating Question 1: CIS Benchmark kubelet"
echo "============================================"

# 1. kubelet config file still exists
check "kubelet config file exists at /var/lib/kubelet/config.yaml" \
  bash -c 'sudo test -f /var/lib/kubelet/config.yaml'

# 2. CIS 4.2.1 - anonymous authentication disabled
check "[CIS 4.2.1] anonymous authentication is disabled" \
  bash -c 'sudo grep -A2 "anonymous:" /var/lib/kubelet/config.yaml | grep -qE "enabled:[[:space:]]*false"'

# 3. CIS 4.2.2 - authorization mode is Webhook (not AlwaysAllow)
check "[CIS 4.2.2] authorization mode is Webhook" \
  bash -c 'sudo grep -A2 "^authorization:" /var/lib/kubelet/config.yaml | grep -qE "mode:[[:space:]]*Webhook"'

check "[CIS 4.2.2] authorization mode is NOT AlwaysAllow" \
  bash -c 'sudo grep -qE "mode:[[:space:]]*AlwaysAllow" /var/lib/kubelet/config.yaml && exit 1 || exit 0'

# 4. CIS 4.2.4 - read only port is 0
check "[CIS 4.2.4] readOnlyPort is 0" \
  bash -c 'sudo grep -qE "^readOnlyPort:[[:space:]]*0[[:space:]]*$" /var/lib/kubelet/config.yaml'

# 5. CIS 4.2.5 - streaming connection idle timeout is not 0
check "[CIS 4.2.5] streamingConnectionIdleTimeout is not 0" \
  bash -c 'VAL=$(sudo grep -E "^streamingConnectionIdleTimeout:" /var/lib/kubelet/config.yaml | awk "{print \$2}"); [[ -n "$VAL" && "$VAL" != "0" && "$VAL" != "0s" ]]'

# 6. kubelet service is active (settings were applied with a restart)
check "kubelet service is active" \
  bash -c 'sudo systemctl is-active --quiet kubelet'

# 7. the read only port is no longer listening
check "port 10255 is not listening" \
  bash -c 'sudo ss -ltn 2>/dev/null | grep -q ":10255 " && exit 1 || exit 0'

# 8. the node is Ready
check "all nodes are Ready" \
  bash -c 'NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk "{print \$2}" | grep -cv "^Ready$"); [[ "$NOT_READY" -eq 0 ]]'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
