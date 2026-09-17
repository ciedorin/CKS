#!/bin/bash
# Validation script for Question 16 - TLS Secret
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
echo " Validating Question 16: TLS Secret"
echo "============================================"

NS="clever-cactus"

# 1. the secret exists and has the right type
check "Secret 'clever-cactus' exists in namespace 'clever-cactus'" \
  kubectl get secret clever-cactus -n clever-cactus

check "the Secret is of type kubernetes.io/tls" \
  bash -c 'T=$(kubectl get secret clever-cactus -n clever-cactus -o jsonpath="{.type}" 2>/dev/null); [[ "$T" == "kubernetes.io/tls" ]]'

check "the Secret contains a tls.crt key" \
  bash -c 'kubectl get secret clever-cactus -n clever-cactus -o jsonpath="{.data.tls\.crt}" 2>/dev/null | grep -q .'

check "the Secret contains a tls.key key" \
  bash -c 'kubectl get secret clever-cactus -n clever-cactus -o jsonpath="{.data.tls\.key}" 2>/dev/null | grep -q .'

# 2. the content matches the provided files
check "tls.crt matches /opt/course/16/clever-cactus.crt" \
  bash -c 'A=$(kubectl get secret clever-cactus -n clever-cactus -o jsonpath="{.data.tls\.crt}" 2>/dev/null | base64 -d | openssl x509 -noout -fingerprint 2>/dev/null); B=$(sudo openssl x509 -in /opt/course/16/clever-cactus.crt -noout -fingerprint 2>/dev/null); [[ -n "$A" && "$A" == "$B" ]]'

check "tls.key matches /opt/course/16/clever-cactus.key" \
  bash -c 'A=$(kubectl get secret clever-cactus -n clever-cactus -o jsonpath="{.data.tls\.key}" 2>/dev/null | base64 -d | sudo tee /tmp/cks-q16.key >/dev/null; openssl rsa -in /tmp/cks-q16.key -noout -modulus 2>/dev/null); B=$(sudo openssl rsa -in /opt/course/16/clever-cactus.key -noout -modulus 2>/dev/null); rm -f /tmp/cks-q16.key; [[ -n "$A" && "$A" == "$B" ]]'

# 3. the deployment was not modified and now runs
check "Deployment 'clever-cactus' still references the Secret 'clever-cactus'" \
  bash -c 'kubectl get deployment clever-cactus -n clever-cactus -o jsonpath="{.spec.template.spec.volumes[*].secret.secretName}" 2>/dev/null | grep -q "clever-cactus"'

check "the Deployment is Available" \
  kubectl wait --for=condition=Available --timeout=120s deployment/clever-cactus -n clever-cactus

check "the pod is Running" \
  bash -c 'kubectl get pods -n clever-cactus --no-headers 2>/dev/null | grep -q Running'

check "the certificate is mounted inside the pod at /etc/nginx/tls" \
  bash -c 'kubectl exec -n clever-cactus deploy/clever-cactus -- test -s /etc/nginx/tls/tls.crt'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
