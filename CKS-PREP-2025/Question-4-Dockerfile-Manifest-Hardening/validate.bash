#!/bin/bash
# Validation script for Question 4 - Dockerfile and manifest hardening
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
echo " Validating Question 4: Dockerfile / manifest"
echo "============================================"

DOCKERFILE="/home/candidate/app/Dockerfile"
DEPLOYMENT="/home/candidate/app/deployment.yaml"

# --- Dockerfile ---------------------------------------------
check "Dockerfile exists at $DOCKERFILE" \
  bash -c 'sudo test -f /home/candidate/app/Dockerfile'

check "Dockerfile no longer contains 'USER root'" \
  bash -c 'sudo grep -qE "^[[:space:]]*USER[[:space:]]+root[[:space:]]*$" /home/candidate/app/Dockerfile && exit 1 || exit 0'

check "Dockerfile switches to the 'nobody' user" \
  bash -c 'sudo grep -qE "^[[:space:]]*USER[[:space:]]+nobody" /home/candidate/app/Dockerfile'

check "only the USER instruction was changed (FROM alpine:3.20 intact)" \
  bash -c 'sudo grep -qE "^FROM[[:space:]]+alpine:3.20$" /home/candidate/app/Dockerfile'

check "only the USER instruction was changed (ENTRYPOINT intact)" \
  bash -c 'sudo grep -qE "^ENTRYPOINT \[\"/app/entrypoint.sh\"\]$" /home/candidate/app/Dockerfile'

check "only the USER instruction was changed (RUN apk instruction intact)" \
  bash -c 'sudo grep -qE "^RUN apk add --no-cache curl$" /home/candidate/app/Dockerfile'

# --- Deployment manifest ------------------------------------
check "Deployment manifest exists at $DEPLOYMENT" \
  bash -c 'sudo test -f /home/candidate/app/deployment.yaml'

check "manifest no longer sets privileged: true" \
  bash -c 'sudo grep -qE "privileged:[[:space:]]*true" /home/candidate/app/deployment.yaml && exit 1 || exit 0'

check "the other securityContext fields were left alone (allowPrivilegeEscalation: false)" \
  bash -c 'sudo grep -qE "allowPrivilegeEscalation:[[:space:]]*false" /home/candidate/app/deployment.yaml'

check "the other securityContext fields were left alone (readOnlyRootFilesystem: true)" \
  bash -c 'sudo grep -qE "readOnlyRootFilesystem:[[:space:]]*true" /home/candidate/app/deployment.yaml'

check "the other securityContext fields were left alone (runAsUser: 10001)" \
  bash -c 'sudo grep -qE "runAsUser:[[:space:]]*10001" /home/candidate/app/deployment.yaml'

check "the workload identity was left alone (name: couch-app)" \
  bash -c 'sudo grep -qE "name:[[:space:]]*couch-app" /home/candidate/app/deployment.yaml'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
