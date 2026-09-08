#!/bin/bash
# Validation script for Question 12 - SBOM
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
echo " Validating Question 12: SBOM"
echo "============================================"

SBOM="/opt/course/12/alpine-sbom.json"

HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, sys

SBOM = "/opt/course/12/alpine-sbom.json"
what = sys.argv[1]

try:
    with open(SBOM) as f:
        doc = json.load(f)
except Exception:
    sys.exit(1)

if what == "json":
    sys.exit(0)

if what == "spdx":
    ok = "spdxVersion" in doc or doc.get("SPDXID") is not None
    sys.exit(0 if ok else 1)

if what == "content":
    blob = json.dumps(doc).lower()
    # the SBOM has to describe the alpine 3.14 image, which ships libcrypto1.1
    sys.exit(0 if ("libcrypto1.1" in blob or "3.14" in blob) else 1)

sys.exit(1)
PY

# --- the Deployment -----------------------------------------
check "Deployment 'alpine' exists in namespace 'alpine'" \
  kubectl get deployment alpine -n alpine

check "the Deployment now has exactly two containers" \
  bash -c 'N=$(kubectl get deployment alpine -n alpine -o jsonpath="{.spec.template.spec.containers[*].name}" 2>/dev/null | wc -w); [[ "$N" -eq 2 ]]'

check "no container uses the vulnerable alpine:3.14 image any more" \
  bash -c 'kubectl get deployment alpine -n alpine -o jsonpath="{.spec.template.spec.containers[*].image}" 2>/dev/null | grep -q "3.14" && exit 1 || exit 0'

check "the alpine:3.17 container was kept" \
  bash -c 'kubectl get deployment alpine -n alpine -o jsonpath="{.spec.template.spec.containers[*].image}" 2>/dev/null | grep -q "3.17"'

check "the alpine:3.20 container was kept" \
  bash -c 'kubectl get deployment alpine -n alpine -o jsonpath="{.spec.template.spec.containers[*].image}" 2>/dev/null | grep -q "3.20"'

check "the Deployment is Available after the change" \
  kubectl wait --for=condition=Available --timeout=120s deployment/alpine -n alpine

# --- the SBOM -----------------------------------------------
check "SBOM file exists at $SBOM" \
  bash -c 'sudo test -s /opt/course/12/alpine-sbom.json'

check "SBOM is valid JSON" \
  bash -c "python3 $HELPER json"

check "SBOM is in SPDX format" \
  bash -c "python3 $HELPER spdx"

check "SBOM describes the alpine 3.14 image (libcrypto1.1)" \
  bash -c "python3 $HELPER content"

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
