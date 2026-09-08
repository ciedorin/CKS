# Question 1 - CIS Benchmark (kubelet)

# Context:
# A CIS Benchmark tool (kube-bench) was run against this kubeadm-provisioned cluster
# and reported a number of FAIL results for the kubelet on this node.

# Task:
# Fix ALL of the following kubelet violations by editing the kubelet configuration
# file at /var/lib/kubelet/config.yaml, then restart the affected component so the
# new settings take effect.
#
# 1. [CIS 4.2.1] Ensure that the --anonymous-auth argument is set to false
# 2. [CIS 4.2.2] Ensure that the --authorization-mode argument is NOT set to AlwaysAllow
#                (it must be Webhook)
# 3. [CIS 4.2.4] Ensure that the --read-only-port argument is set to 0
# 4. [CIS 4.2.5] Ensure that the --streaming-connection-idle-timeout argument is not 0
#                (use 4h0m0s)
#
# The node must still be Ready and the kubelet service must be active when you are done.

# Hint:
# kube-bench can be run with:
#   kube-bench run --targets node
# If kube-bench is not installed, work directly from the CIS control list above.

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Reference -> Configuration APIs -> kubelet Configuration (v1beta1)
# https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
# Tasks -> Administer a Cluster -> Set Kubelet Parameters Via A Configuration File
# https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
