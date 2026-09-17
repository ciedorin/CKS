# Question 2 - API server hardening

# Context:
# The kube-apiserver on this control plane node has been misconfigured. It currently
# accepts anonymous requests, authorizes everything, and is missing an important
# admission controller. On top of that, somebody bound cluster-admin to the
# system:anonymous user.

# Task:
# 1. Configure the kube-apiserver so that anonymous authentication is forbidden
#    (--anonymous-auth=false)
# 2. Configure the authorization mode to be exactly: Node,RBAC
# 3. Enable the NodeRestriction admission controller (keep the plugins that are
#    already enabled)
# 4. Remove the ClusterRoleBinding named system:anonymous
#
# The API server must be healthy and serving again once you are finished.

# Verify (anonymous requests must be rejected with 401):
#   curl -k https://127.0.0.1:6443/api/v1/nodes

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Reference -> Command line tools reference -> kube-apiserver
# https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
# Reference -> Access the API -> Using Admission Controllers -> NodeRestriction
# https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction
# Reference -> Access the API -> Using Node Authorization
# https://kubernetes.io/docs/reference/access-authn-authz/node/
