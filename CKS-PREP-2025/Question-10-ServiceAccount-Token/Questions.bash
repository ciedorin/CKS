# Question 10 - ServiceAccount token

# Context:
# The Deployment stats-monitor in the namespace monitoring runs with the
# ServiceAccount stats-monitor-sa. Right now every pod using that ServiceAccount
# automatically receives API credentials at the default location
# /var/run/secrets/kubernetes.io/serviceaccount - even pods that do not need them.
#
# The stats-monitor application does need a token, but it expects to read it from
# its own path.

# Task:
# 1. Turn OFF the automounting of API credentials for the ServiceAccount
#    stats-monitor-sa in the namespace monitoring.
#
# 2. Modify the Deployment stats-monitor in the namespace monitoring so that the
#    ServiceAccount token is mounted at:
#
#       /var/run/secrets/stats-monitor
#
#    Use a projected volume with a serviceAccountToken source (do NOT re-enable
#    the automount, and do not mount a long lived Secret).

# Verify:
#   kubectl exec -n monitoring deploy/stats-monitor -- ls /var/run/secrets/stats-monitor
#   kubectl exec -n monitoring deploy/stats-monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount  # must fail

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Tasks -> Configure Pods and Containers -> Configure Service Accounts for Pods
# https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
# Reference -> Access the API -> Service Account Tokens (projected volume)
# https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection
