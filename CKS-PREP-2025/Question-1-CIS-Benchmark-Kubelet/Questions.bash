# Question 1 - CIS Benchmark (kubelet)

# Context:
# This kubeadm-provisioned cluster has to be audited against the CIS Kubernetes
# Benchmark. The tool kube-bench is installed on this node.

# Task:
#
# STEP 1 - run the benchmark against the kubelet and look at section 4.2:
#
#     sudo kube-bench run --targets node
#
#   (if the benchmark version is not auto detected, force one:
#     sudo kube-bench run --targets node --benchmark cis-1.9 )
#
# STEP 2 - fix ALL of the following FAIL results by editing the kubelet
#          configuration file /var/lib/kubelet/config.yaml, then restart the
#          affected component so the new settings take effect:
#
#   a) Ensure that the --anonymous-auth argument is set to false
#   b) Ensure that the --authorization-mode argument is not set to AlwaysAllow
#      (it must be Webhook)
#   c) Verify that the --read-only-port argument is set to 0
#   d) Ensure that the --streaming-connection-idle-timeout argument is not set to 0
#      (use 4h0m0s)
#
#   In CIS 1.8/1.9 these are the controls 4.2.1, 4.2.2, 4.2.4 and 4.2.5.
#   The numbering can shift between benchmark versions - the descriptions above
#   are what counts.
#
# STEP 3 - run the benchmark again and confirm that those four controls now
#          report PASS:
#
#     sudo kube-bench run --targets node
#
# The node must still be Ready and the kubelet service must be active when you
# are done. Other FAIL results that were already there may be left alone.

# Useful:
#   sudo kube-bench run --targets node | grep -E '^\[(FAIL|WARN)\]'
#   sudo kube-bench run --targets node --check 4.2.1,4.2.2,4.2.4,4.2.5

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Reference -> Configuration APIs -> kubelet Configuration (v1beta1)
# https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/
# Tasks -> Administer a Cluster -> Set Kubelet Parameters Via A Configuration File
# https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/
# kube-bench
# https://github.com/aquasecurity/kube-bench
