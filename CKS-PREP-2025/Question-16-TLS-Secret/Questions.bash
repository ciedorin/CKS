# Question 16 - TLS Secret

# Context:
# The Deployment "clever-cactus" in the namespace clever-cactus mounts a Secret
# named "clever-cactus" at /etc/nginx/tls. That Secret does not exist yet, so the
# pod cannot start.
#
# The certificate and the private key are on the node:
#
#   /opt/course/16/clever-cactus.crt
#   /opt/course/16/clever-cactus.key

# Task:
# Create a TLS Secret named "clever-cactus" in the namespace clever-cactus using
# the given certificate and key files.
#
# The Secret must be of type kubernetes.io/tls.
# Do not modify the Deployment - it already references the Secret.
# The pod must be Running afterwards.

# Verify:
#   kubectl get secret clever-cactus -n clever-cactus
#   kubectl get pods -n clever-cactus

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Configuration -> Secrets -> TLS Secrets
# https://kubernetes.io/docs/concepts/configuration/secret/#tls-secrets
# Reference -> kubectl -> kubectl create secret tls
# https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#-em-tls-em-
