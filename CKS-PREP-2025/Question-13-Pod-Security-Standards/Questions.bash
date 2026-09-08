# Question 13 - Pod Security Standards

# Context:
# All user namespaces in this cluster enforce the "restricted" Pod Security
# Standard. The Deployment "confidential-app" in the namespace confidential is
# not compliant with it, which is why none of its pods can be scheduled.

# Task:
# 1. Find out why the pods of the Deployment confidential-app are not created
# 2. Modify the Deployment so that it complies with the restricted
#    Pod Security Standard
# 3. Verify that the pods are running afterwards
#
# Do not change the enforcement level of the namespace and do not add any
# exemption - fix the workload.

# Hints:
#   kubectl get events -n confidential --sort-by=.lastTimestamp
#   kubectl describe rs -n confidential
#   kubectl label --list namespace confidential

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Security -> Pod Security Standards (see the "Restricted" table)
# https://kubernetes.io/docs/concepts/security/pod-security-standards/
# Concepts -> Security -> Pod Security Admission
# https://kubernetes.io/docs/concepts/security/pod-security-admission/
