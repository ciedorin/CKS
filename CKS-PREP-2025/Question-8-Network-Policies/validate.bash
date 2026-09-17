#!/bin/bash
# Validation script for Question 8 - NetworkPolicies
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
echo " Validating Question 8: NetworkPolicies"
echo "============================================"

HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, subprocess, sys

what = sys.argv[1]

def get(ns, name):
    r = subprocess.run(["kubectl", "get", "networkpolicy", name, "-n", ns, "-o", "json"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(1)
    return json.loads(r.stdout)["spec"]

if what == "deny-all-pods":
    spec = get("prod", "deny-policy")
    sys.exit(0 if spec.get("podSelector") in ({}, None) else 1)

if what == "deny-ingress-type":
    spec = get("prod", "deny-policy")
    sys.exit(0 if "Ingress" in (spec.get("policyTypes") or []) else 1)

if what == "deny-no-rules":
    spec = get("prod", "deny-policy")
    sys.exit(0 if not spec.get("ingress") else 1)

if what == "allow-ingress-type":
    spec = get("data", "allow-from-prod")
    sys.exit(0 if "Ingress" in (spec.get("policyTypes") or []) else 1)

if what == "allow-from-prod-ns":
    spec = get("data", "allow-from-prod")
    for rule in spec.get("ingress") or []:
        for src in rule.get("from") or []:
            sel = src.get("namespaceSelector")
            if not sel:
                continue
            labels = sel.get("matchLabels") or {}
            if labels.get("env") == "prod":
                sys.exit(0)
            if labels.get("kubernetes.io/metadata.name") == "prod":
                sys.exit(0)
            if labels.get("name") == "prod":
                sys.exit(0)
            for expr in sel.get("matchExpressions") or []:
                if "prod" in [str(v) for v in (expr.get("values") or [])]:
                    sys.exit(0)
    sys.exit(1)

if what == "allow-not-too-open":
    spec = get("data", "allow-from-prod")
    rules = spec.get("ingress") or []
    if not rules:
        sys.exit(1)
    for rule in rules:
        froms = rule.get("from")
        # an empty "from" (or a missing one) allows every source
        if not froms:
            sys.exit(1)
        for src in froms:
            sel = src.get("namespaceSelector")
            pod = src.get("podSelector")
            ipb = src.get("ipBlock")
            if ipb:
                sys.exit(1)                       # ip based sources are not asked for
            if sel is not None and sel == {}:
                sys.exit(1)                       # matches every namespace
            if sel is None and pod is not None:
                sys.exit(1)                       # same namespace pods, not prod
    sys.exit(0)

sys.exit(1)
PY

# --- deny-policy in prod ------------------------------------
check "NetworkPolicy 'deny-policy' exists in namespace 'prod'" \
  kubectl get networkpolicy deny-policy -n prod

check "deny-policy applies to all pods in the namespace (empty podSelector)" \
  bash -c "python3 $HELPER deny-all-pods"

check "deny-policy has policyTypes: Ingress" \
  bash -c "python3 $HELPER deny-ingress-type"

check "deny-policy defines no ingress rules (blocks everything)" \
  bash -c "python3 $HELPER deny-no-rules"

# --- allow-from-prod in data --------------------------------
check "NetworkPolicy 'allow-from-prod' exists in namespace 'data'" \
  kubectl get networkpolicy allow-from-prod -n data

check "allow-from-prod has policyTypes: Ingress" \
  bash -c "python3 $HELPER allow-ingress-type"

check "allow-from-prod allows ingress from the prod namespace (namespaceSelector)" \
  bash -c "python3 $HELPER allow-from-prod-ns"

check "allow-from-prod is not more permissive than required" \
  bash -c "python3 $HELPER allow-not-too-open"

# --- the workloads are still there --------------------------
check "Deployment 'db' still exists in namespace 'data'" \
  kubectl get deployment db -n data

check "Deployment 'web' still exists in namespace 'prod'" \
  kubectl get deployment web -n prod

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."

echo ""
echo "============================================"
echo " Manual connectivity validation"
echo "============================================"
echo "These require a CNI that enforces NetworkPolicies:"
echo "  kubectl exec -n prod deploy/client -- curl -s --max-time 5 -o /dev/null -w 'prod->data:  %{http_code}\n' http://db.data.svc.cluster.local   # expect 200"
echo "  kubectl exec -n other deploy/intruder -- curl -s --max-time 5 -o /dev/null -w 'other->data: %{http_code}\n' http://db.data.svc.cluster.local  # expect timeout"
echo "  kubectl exec -n other deploy/intruder -- curl -s --max-time 5 -o /dev/null -w 'other->prod: %{http_code}\n' http://web.prod.svc.cluster.local  # expect timeout"

exit $FAIL
