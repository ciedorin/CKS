#!/bin/bash
# Validation script for Question 7 - Audit logging
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
echo " Validating Question 7: Audit logging"
echo "============================================"

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
POLICY="/etc/kubernetes/policy/audit-policy.yaml"
AUDIT_LOG="/etc/kubernetes/audit.logs.txt"

# policy parser helper
HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import sys

try:
    import yaml
except ImportError:
    print("python3 yaml module missing - install python3-yaml", file=sys.stderr)
    sys.exit(1)

what = sys.argv[1]

with open("/etc/kubernetes/policy/audit-policy.yaml") as f:
    policy = yaml.safe_load(f) or {}

rules = policy.get("rules") or []

def resources_of(rule):
    out = []
    for group in rule.get("resources") or []:
        for res in group.get("resources") or []:
            out.append(res)
    return out

def index_of(pred):
    for i, rule in enumerate(rules):
        if pred(rule):
            return i
    return -1

if what == "kind":
    sys.exit(0 if policy.get("kind") == "Policy"
             and str(policy.get("apiVersion", "")).startswith("audit.k8s.io/") else 1)

if what == "namespaces":
    i = index_of(lambda r: r.get("level") == "RequestResponse"
                 and "namespaces" in resources_of(r))
    sys.exit(0 if i >= 0 else 1)

if what == "deployments":
    i = index_of(lambda r: r.get("level") == "Request"
                 and "deployments" in resources_of(r)
                 and "webapps" in (r.get("namespaces") or []))
    sys.exit(0 if i >= 0 else 1)

if what == "cm-secrets":
    have_cm = index_of(lambda r: r.get("level") == "Metadata"
                       and "configmaps" in resources_of(r)) >= 0
    have_secret = index_of(lambda r: r.get("level") == "Metadata"
                           and "secrets" in resources_of(r)) >= 0
    sys.exit(0 if have_cm and have_secret else 1)

if what == "catch-all":
    i = index_of(lambda r: r.get("level") == "Metadata"
                 and not r.get("resources")
                 and not r.get("namespaces")
                 and not r.get("users")
                 and not r.get("verbs"))
    sys.exit(0 if i == len(rules) - 1 and i >= 0 else 1)

if what == "order":
    # the catch-all Metadata rule must not shadow the more specific rules
    ns = index_of(lambda r: r.get("level") == "RequestResponse"
                  and "namespaces" in resources_of(r))
    dep = index_of(lambda r: r.get("level") == "Request"
                   and "deployments" in resources_of(r))
    catch = index_of(lambda r: r.get("level") == "Metadata" and not r.get("resources"))
    sys.exit(0 if ns >= 0 and dep >= 0 and catch > ns and catch > dep else 1)

sys.exit(1)
PY

# --- the audit policy ---------------------------------------
check "audit policy exists at $POLICY" \
  bash -c 'sudo test -f /etc/kubernetes/policy/audit-policy.yaml'

check "audit policy is a valid audit.k8s.io Policy object" \
  bash -c "python3 $HELPER kind"

check "[a] namespaces interactions are logged at RequestResponse level" \
  bash -c "python3 $HELPER namespaces"

check "[b] deployments in namespace webapps are logged at Request level" \
  bash -c "python3 $HELPER deployments"

check "[c] configmaps and secrets are logged at Metadata level" \
  bash -c "python3 $HELPER cm-secrets"

check "[d] a catch-all Metadata rule is the last rule" \
  bash -c "python3 $HELPER catch-all"

check "rule order does not shadow the specific rules" \
  bash -c "python3 $HELPER order"

# --- the API server flags -----------------------------------
check "kube-apiserver has --audit-policy-file pointing at the policy" \
  bash -c 'sudo grep -qE -- "--audit-policy-file=/etc/kubernetes/policy/audit-policy.yaml" /etc/kubernetes/manifests/kube-apiserver.yaml'

check "kube-apiserver has --audit-log-path=/etc/kubernetes/audit.logs.txt" \
  bash -c 'sudo grep -qE -- "--audit-log-path=/etc/kubernetes/audit.logs.txt" /etc/kubernetes/manifests/kube-apiserver.yaml'

check "kube-apiserver has --audit-log-maxbackup=2" \
  bash -c 'sudo grep -qE -- "--audit-log-maxbackup=2([^0-9]|$)" /etc/kubernetes/manifests/kube-apiserver.yaml'

check "kube-apiserver has --audit-log-maxage=10" \
  bash -c 'sudo grep -qE -- "--audit-log-maxage=10([^0-9]|$)" /etc/kubernetes/manifests/kube-apiserver.yaml'

check "the policy directory is mounted into the static pod" \
  bash -c 'sudo grep -qE "path:[[:space:]]*/etc/kubernetes/policy" /etc/kubernetes/manifests/kube-apiserver.yaml'

check "the audit log path is mounted into the static pod" \
  bash -c 'sudo grep -qE "(path|mountPath):[[:space:]]*/etc/kubernetes/audit.logs.txt" /etc/kubernetes/manifests/kube-apiserver.yaml'

# --- the running result -------------------------------------
check "API server is healthy" \
  bash -c 'for i in $(seq 1 20); do kubectl get --raw /healthz >/dev/null 2>&1 && exit 0; sleep 3; done; exit 1'

check "the audit log file exists and is not empty" \
  bash -c 'kubectl get ns >/dev/null 2>&1; sleep 3; sudo test -s /etc/kubernetes/audit.logs.txt'

check "namespaces interactions really land in the audit log" \
  bash -c 'kubectl get ns >/dev/null 2>&1; sleep 3; sudo grep -q "\"resource\":\"namespaces\"" /etc/kubernetes/audit.logs.txt'

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
