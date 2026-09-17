#!/bin/bash
# Validation script for Question 9 - Ingress with TLS
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
echo " Validating Question 9: Ingress with TLS"
echo "============================================"

HELPER="$(mktemp)"
cat > "$HELPER" <<'PY'
import json, subprocess, sys

what = sys.argv[1]

r = subprocess.run(["kubectl", "get", "ingress", "web", "-n", "prod", "-o", "json"],
                   capture_output=True, text=True)
if r.returncode != 0:
    sys.exit(1)

obj = json.loads(r.stdout)
spec = obj.get("spec") or {}
annotations = (obj.get("metadata") or {}).get("annotations") or {}
rules = spec.get("rules") or []
tls = spec.get("tls") or []

if what == "host":
    sys.exit(0 if any(rule.get("host") == "web.k8s.local" for rule in rules) else 1)

if what == "backend":
    for rule in rules:
        if rule.get("host") != "web.k8s.local":
            continue
        for path in ((rule.get("http") or {}).get("paths") or []):
            svc = ((path.get("backend") or {}).get("service") or {})
            port = (svc.get("port") or {})
            if svc.get("name") == "web" and (port.get("number") == 80 or port.get("name") == "http"):
                sys.exit(0)
    sys.exit(1)

if what == "allpaths":
    for rule in rules:
        if rule.get("host") != "web.k8s.local":
            continue
        for path in ((rule.get("http") or {}).get("paths") or []):
            p = path.get("path") or "/"
            ptype = path.get("pathType")
            if p == "/" and ptype in ("Prefix", "ImplementationSpecific"):
                sys.exit(0)
    sys.exit(1)

if what == "tls":
    for entry in tls:
        if entry.get("secretName") == "web-cert":
            sys.exit(0)
    sys.exit(1)

if what == "tls-host":
    for entry in tls:
        if entry.get("secretName") == "web-cert" and "web.k8s.local" in (entry.get("hosts") or []):
            sys.exit(0)
    sys.exit(1)

if what == "redirect":
    for key in ("nginx.ingress.kubernetes.io/ssl-redirect",
                "nginx.ingress.kubernetes.io/force-ssl-redirect"):
        if str(annotations.get(key, "")).lower() == "true":
            sys.exit(0)
    sys.exit(1)

if what == "class":
    if spec.get("ingressClassName") == "nginx":
        sys.exit(0)
    if annotations.get("kubernetes.io/ingress.class") == "nginx":
        sys.exit(0)
    sys.exit(1)

sys.exit(1)
PY

check "Ingress 'web' exists in namespace 'prod'" \
  kubectl get ingress web -n prod

check "Ingress uses the nginx IngressClass" \
  bash -c "python3 $HELPER class"

check "Ingress routes the host web.k8s.local" \
  bash -c "python3 $HELPER host"

check "Ingress matches all paths (path '/' with pathType Prefix)" \
  bash -c "python3 $HELPER allpaths"

check "Ingress forwards to Service 'web' on port 80" \
  bash -c "python3 $HELPER backend"

check "Ingress terminates TLS with Secret 'web-cert'" \
  bash -c "python3 $HELPER tls"

check "the TLS block covers the host web.k8s.local" \
  bash -c "python3 $HELPER tls-host"

check "HTTP to HTTPS redirect is configured" \
  bash -c "python3 $HELPER redirect"

check "Secret 'web-cert' is of type kubernetes.io/tls" \
  bash -c 'T=$(kubectl get secret web-cert -n prod -o jsonpath="{.type}" 2>/dev/null); [[ "$T" == "kubernetes.io/tls" ]]'

check "Service 'web' still exists in namespace 'prod'" \
  kubectl get service web -n prod

rm -f "$HELPER"

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."

echo ""
echo "============================================"
echo " Manual validation"
echo "============================================"
echo "  CONTROLLER_IP=\$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')"
echo "  echo \"\$CONTROLLER_IP web.k8s.local\" | sudo tee -a /etc/hosts"
echo "  curl -kIL http://web.k8s.local     # expect 308 redirect to https"
echo "  curl -k   https://web.k8s.local    # expect the nginx welcome page"

exit $FAIL
