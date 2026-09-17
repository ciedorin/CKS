# Question 15 - Istio mutual TLS

# Context:
# Istio is installed in this cluster (namespace istio-system). The namespace mtls
# runs two workloads, "frontend" and "backend". Their pods currently show 1/1
# containers, which means no Envoy sidecar has been injected, so their traffic
# is not encrypted by the mesh.

# Task:
# 1. Make sure that ALL pods in the namespace mtls have the istio-proxy sidecar
#    injected. Existing pods have to be recreated for that to take effect.
#
# 2. Configure mutual TLS in STRICT mode for ALL workloads in the namespace mtls,
#    so that plaintext traffic is rejected.
#    The configuration must apply to the whole namespace, not to a single workload.

# Verify:
#   kubectl get pods -n mtls            # every pod must be 2/2
#   kubectl get peerauthentication -n mtls
#   istioctl x describe pod -n mtls <pod-name>

# Documentation Reference
# Istio - Installing the sidecar / automatic injection
# https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/
# Istio - Mutual TLS Migration / PeerAuthentication
# https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/
# https://istio.io/latest/docs/reference/config/security/peer_authentication/
