# Question 7 - Audit logging

# Context:
# Auditing is not enabled on this cluster. An (empty) audit policy skeleton has
# been placed at /etc/kubernetes/policy/audit-policy.yaml

# Task:
# Reconfigure the kube-apiserver of this cluster to enable auditing.
#
# 1. Use the audit policy file /etc/kubernetes/policy/audit-policy.yaml
# 2. Store the audit logs at /etc/kubernetes/audit.logs.txt
# 3. Retain a maximum of 2 audit log files, for a maximum of 10 days
#
# Write the audit policy so that it logs:
#
#   a) all "namespaces" interactions at the RequestResponse level
#   b) the request body of "deployments" interactions inside the namespace webapps
#      (i.e. the Request level)
#   c) ConfigMap and Secret interactions in ALL namespaces at the Metadata level
#   d) every other request at the Metadata level
#
# Remember that the policy is evaluated top down: the FIRST matching rule wins,
# so the order of the rules matters.
#
# The API server must be healthy again and the audit log file must be written to.

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Tasks -> Administer a Cluster -> Auditing
# https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/
