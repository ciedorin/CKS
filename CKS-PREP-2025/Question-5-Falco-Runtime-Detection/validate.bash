#!/bin/bash
# Validation script for Question 5 - Falco runtime detection
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
echo " Validating Question 5: Falco / misbehaving pod"
echo "============================================"

# work out which workload was the misbehaving one by looking at the scripts
CULPRIT=""
for n in alpha beta gamma; do
  if kubectl get configmap ollama-scripts -n ollama -o jsonpath="{.data.$n\.sh}" 2>/dev/null | grep -q "/dev/mem"; then
    CULPRIT="$n"
  fi
done

if [[ -z "$CULPRIT" ]]; then
  echo "  FAIL: could not determine the misbehaving workload - is the lab set up?"
  echo ""
  echo "Results: 0/1 passed, 1 failed"
  exit 1
fi

export CULPRIT

# 1. namespace still exists
check "namespace 'ollama' exists" \
  kubectl get namespace ollama

# 2. the misbehaving deployment is scaled to zero
check "the misbehaving Deployment (ollama-$CULPRIT) is scaled to 0 replicas" \
  bash -c 'R=$(kubectl get deployment ollama-$CULPRIT -n ollama -o jsonpath="{.spec.replicas}" 2>/dev/null); [[ "$R" == "0" ]]'

# 3. no pods of the misbehaving deployment remain
check "no pods of ollama-$CULPRIT are running" \
  bash -c 'N=$(kubectl get pods -n ollama -l component=$CULPRIT --no-headers 2>/dev/null | wc -l); [[ "$N" -eq 0 ]]'

# 4. the other two deployments were left alone
for n in alpha beta gamma; do
  if [[ "$n" == "$CULPRIT" ]]; then
    continue
  fi
  export OTHER="$n"
  check "the healthy Deployment ollama-$n is still running" \
    bash -c 'R=$(kubectl get deployment ollama-$OTHER -n ollama -o jsonpath="{.spec.replicas}" 2>/dev/null); [[ -n "$R" && "$R" -ge 1 ]]'
done

# 5. exactly one deployment was scaled down
check "exactly one Deployment in the namespace is scaled to zero" \
  bash -c 'N=$(kubectl get deployments -n ollama -o jsonpath="{range .items[*]}{.spec.replicas}{\"\n\"}{end}" 2>/dev/null | grep -c "^0$"); [[ "$N" -eq 1 ]]'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
