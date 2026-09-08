# Question 4 - Dockerfile and manifest hardening

# Context:
# A team handed over a container image build and its Kubernetes manifest.
# Both contain exactly one prominent security issue each.

# Task:
# 1. Edit /home/candidate/app/Dockerfile
#    Fix the ONE instruction that is a prominent security issue.
#    - Change ONE line only.
#    - The container must not run as root: use the user "nobody".
#    - Do NOT build the image.
#
# 2. Edit /home/candidate/app/deployment.yaml
#    Fix the ONE field that is a prominent security issue.
#    - Change ONE field only. Leave every other field untouched.
#    - Do NOT apply the manifest.

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Tasks -> Configure Pods and Containers -> Configure a Security Context for a Pod or Container
# https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
# Concepts -> Security -> Pod Security Standards
# https://kubernetes.io/docs/concepts/security/pod-security-standards/
