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

# --- the kubelet configuration ------------------------------
check "kubelet config file exists at /var/lib/kubelet/config.yaml" \
  bash -c 'sudo test -f /var/lib/kubelet/config.yaml'

check "[4.2.1] anonymous authentication is disabled" \
  bash -c 'sudo grep -A2 "anonymous:" /var/lib/kubelet/config.yaml | grep -qE "enabled:[[:space:]]*false"'

check "[4.2.2] authorization mode is Webhook" \
  bash -c 'sudo grep -A2 "^authorization:" /var/lib/kubelet/config.yaml | grep -qE "mode:[[:space:]]*Webhook"'

check "[4.2.2] authorization mode is NOT AlwaysAllow" \
  bash -c 'sudo grep -qE "mode:[[:space:]]*AlwaysAllow" /var/lib/kubelet/config.yaml && exit 1 || exit 0'

check "[4.2.4] readOnlyPort is 0" \
  bash -c 'sudo grep -qE "^readOnlyPort:[[:space:]]*0[[:space:]]*$" /var/lib/kubelet/config.yaml'

check "[4.2.5] streamingConnectionIdleTimeout is not 0" \
  bash -c 'VAL=$(sudo grep -E "^streamingConnectionIdleTimeout:" /var/lib/kubelet/config.yaml | awk "{print \$2}"); [[ -n "$VAL" && "$VAL" != "0" && "$VAL" != "0s" ]]'

# --- the settings are actually live -------------------------
check "kubelet service is active" \
  bash -c 'sudo systemctl is-active --quiet kubelet'

check "port 10255 is not listening" \
  bash -c 'sudo ss -ltn 2>/dev/null | grep -q ":10255 " && exit 1 || exit 0'

check "all nodes are Ready" \
  bash -c 'NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | awk "{print \$2}" | grep -cv "^Ready$"); [[ "$NOT_READY" -eq 0 ]]'

# --- the benchmark itself -----------------------------------
echo ""
echo "--- kube-bench verification ---"

if command -v kube-bench >/dev/null 2>&1; then
  KB_OUT="$(mktemp)"
  sudo kube-bench run --targets node --noremediations 2>/dev/null \
    | sed 's/\x1b\[[0-9;]*m//g' > "$KB_OUT"

  if [[ -s "$KB_OUT" ]]; then
    export KB_OUT
    check "kube-bench: --anonymous-auth is set to false" \
      bash -c 'grep -i "anonymous-auth argument is set to false" "$KB_OUT" | grep -q "^\[PASS\]"'

    check "kube-bench: --authorization-mode is not AlwaysAllow" \
      bash -c 'grep -i "authorization-mode argument is not set to AlwaysAllow" "$KB_OUT" | grep -q "^\[PASS\]"'

    check "kube-bench: --read-only-port is set to 0" \
      bash -c 'grep -i "read-only-port argument is set to 0" "$KB_OUT" | grep -q "^\[PASS\]"'

    check "kube-bench: --streaming-connection-idle-timeout is not 0" \
      bash -c 'grep -i "streaming-connection-idle-timeout argument is not set to 0" "$KB_OUT" | grep -q "^\[PASS\]"'

    echo ""
    echo "  Remaining FAIL results reported by kube-bench (informational):"
    grep -E "^\[FAIL\]" "$KB_OUT" | head -10 | sed 's/^/    /'
  else
    echo "  SKIP: kube-bench produced no output - run it by hand:"
    echo "        sudo kube-bench run --targets node"
  fi
  rm -f "$KB_OUT"
else
  echo "  SKIP: kube-bench is not installed on this node."
  echo "        Re-run the lab setup, or install it from"
  echo "        https://github.com/aquasecurity/kube-bench/releases"
fi

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
