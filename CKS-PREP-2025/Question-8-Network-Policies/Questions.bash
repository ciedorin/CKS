# Question 8 - NetworkPolicies

# Context:
# Three namespaces exist:
#   prod   - labelled env=prod, runs the Deployment "web" (Service web) and a "client" pod
#   data   - runs the Deployment "db" (Service db)
#   other  - runs an "intruder" pod that must not reach the database
#
# There are currently no NetworkPolicies in the cluster.

# Task:
# 1. Create a NetworkPolicy named "deny-policy" in the namespace prod that
#    blocks ALL incoming (ingress) traffic to every pod in that namespace.
#
# 2. Create a NetworkPolicy named "allow-from-prod" in the namespace data that
#    allows incoming traffic ONLY from pods running in the namespace prod.
#    Use the label of the prod namespace to select it.
#    No other source may be allowed.

# Verify:
#   # from prod -> data : allowed
#   kubectl exec -n prod deploy/client -- curl -s --max-time 5 -o /dev/null -w "%{http_code}\n" http://db.data.svc.cluster.local
#   # from other -> data : blocked
#   kubectl exec -n other deploy/intruder -- curl -s --max-time 5 -o /dev/null -w "%{http_code}\n" http://db.data.svc.cluster.local
#   # anything -> prod : blocked
#   kubectl exec -n other deploy/intruder -- curl -s --max-time 5 -o /dev/null -w "%{http_code}\n" http://web.prod.svc.cluster.local

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Services, Load Balancing, and Networking -> Network Policies
# https://kubernetes.io/docs/concepts/services-networking/network-policies/
