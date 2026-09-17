# Question 3 - ImagePolicyWebhook

# Context:
# The cluster must reject unsigned/untrusted container images before they are admitted.
# An external image policy service will be used for this. Its kubeconfig has already
# been placed on the control plane node at:
#
#   /etc/kubernetes/admission/kubeconf.yaml
#
# An admission configuration file exists at /etc/kubernetes/admission/config.yaml
# but it is incomplete.

# Task:
# 1. Complete /etc/kubernetes/admission/config.yaml so that it configures the
#    ImagePolicyWebhook plugin:
#      - it must point at the kubeconfig /etc/kubernetes/admission/kubeconf.yaml
#      - allowTTL, denyTTL and retryBackoff may keep sensible values
#      - defaultAllow MUST be false, so that images are rejected when the webhook
#        cannot be reached (fail closed)
# 2. Enable the ImagePolicyWebhook admission plugin on the kube-apiserver
#    (keep the plugins that are already enabled)
# 3. Point the kube-apiserver at the admission configuration with
#      --admission-control-config-file=/etc/kubernetes/admission/config.yaml
# 4. Make sure the /etc/kubernetes/admission directory is available inside the
#    kube-apiserver static pod: add the volume AND the volumeMount
#
# The API server must come back up. Because the webhook backend does not actually
# exist and defaultAllow is false, creating a new Pod must now be REJECTED.

# Verify:
#   kubectl run test-image --image=nginx
#   # expected: Error ... failed to call webhook / images not allowed

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Reference -> Access the API -> Using Admission Controllers -> ImagePolicyWebhook
# https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#imagepolicywebhook
