#!/bin/bash
# Validation script for Question 3 - ImagePolicyWebhook
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
echo " Validating Question 3: ImagePolicyWebhook"
echo "============================================"

# 1. the admission configuration file exists
check "admission config exists at /etc/kubernetes/admission/config.yaml" \
  bash -c 'sudo test -f /etc/kubernetes/admission/config.yaml'

# 2. it configures the ImagePolicyWebhook plugin
check "admission config declares the ImagePolicyWebhook plugin" \
  bash -c 'sudo grep -qE "name:[[:space:]]*ImagePolicyWebhook" /etc/kubernetes/admission/config.yaml'

check "admission config has an imagePolicy section" \
  bash -c 'sudo grep -q "imagePolicy:" /etc/kubernetes/admission/config.yaml'

# 3. it points at the provided webhook kubeconfig
check "imagePolicy.kubeConfigFile points at the webhook kubeconfig" \
  bash -c 'KC=$(sudo grep -oP "(?<=kubeConfigFile:)\s*\S+" /etc/kubernetes/admission/config.yaml | tr -d " "); [[ -n "$KC" ]] && sudo test -f "$KC"'

# 4. it fails closed
check "imagePolicy.defaultAllow is false (fail closed)" \
  bash -c 'sudo grep -qE "defaultAllow:[[:space:]]*false" /etc/kubernetes/admission/config.yaml'

# 5. the plugin is enabled on the API server
check "kube-apiserver enables the ImagePolicyWebhook plugin" \
  bash -c 'sudo grep -oP "(?<=--enable-admission-plugins=)\S+" /etc/kubernetes/manifests/kube-apiserver.yaml | head -1 | grep -q "ImagePolicyWebhook"'

# 6. the API server is pointed at the admission config file
check "kube-apiserver has --admission-control-config-file set correctly" \
  bash -c 'sudo grep -qE -- "--admission-control-config-file=/etc/kubernetes/admission/config.yaml" /etc/kubernetes/manifests/kube-apiserver.yaml'

# 7. the directory is mounted into the static pod
check "kube-apiserver has a volumeMount for /etc/kubernetes/admission" \
  bash -c 'sudo grep -qE "mountPath:[[:space:]]*/etc/kubernetes/admission" /etc/kubernetes/manifests/kube-apiserver.yaml'

check "kube-apiserver has a hostPath volume for /etc/kubernetes/admission" \
  bash -c 'sudo grep -qE "path:[[:space:]]*/etc/kubernetes/admission" /etc/kubernetes/manifests/kube-apiserver.yaml'

# 8. the API server survived the change
check "API server is healthy" \
  bash -c 'for i in $(seq 1 20); do kubectl get --raw /healthz >/dev/null 2>&1 && exit 0; sleep 3; done; exit 1'

# 9. pod creation is now rejected by the webhook (fail closed)
check "creating a Pod is rejected by the image policy webhook" \
  bash -c 'kubectl run cks-q3-probe --image=nginx --dry-run=server >/dev/null 2>&1 && exit 1 || exit 0'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
