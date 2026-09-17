# Question 6 - Container immutability

# Context:
# The Deployment lamp-deployment in the namespace lamp runs two containers
# (apache and mysql). Neither of them has any security context configured.

# Task:
# Modify the Deployment lamp-deployment in namespace lamp so that its containers:
#
# 1. run with the user ID 20004
# 2. use a read-only root filesystem
# 3. are not allowed to escalate privileges
#
# All containers of the Deployment must be covered.
# The pods must be running again after your change.

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Tasks -> Configure Pods and Containers -> Configure a Security Context for a Pod or Container
# https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
# Reference -> Kubernetes API -> Workload Resources -> Pod -> SecurityContext
# https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#security-context-1
