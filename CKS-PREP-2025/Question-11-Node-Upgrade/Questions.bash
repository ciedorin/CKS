# Question 11 - Node upgrade

# Context:
# The cluster was upgraded, but one node was left behind on an older version.
# Find it with:
#
#   kubectl get nodes
#
# In this lab the worker node is called "compute-0" (on Killercoda it is usually
# called "node01"). Use whatever name your cluster reports.

# Task:
# Upgrade the worker node so that it runs the SAME version as the control plane.
#
# 1. Drain the node so that workloads are moved away
# 2. Upgrade kubeadm on that node
# 3. Run the node upgrade with kubeadm
# 4. Upgrade kubelet and kubectl, then restart the kubelet
# 5. Uncordon the node again
#
# When you are done every node must be Ready, schedulable, and report the same
# version as the control plane.

# Careful:
#  - the control plane must NOT be upgraded, only the worker node
#  - kubeadm/kubelet/kubectl are held by apt: use --allow-change-held-packages

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Tasks -> Administer a Cluster -> Upgrade A Cluster -> Upgrade worker nodes
# https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-worker-nodes
# Tasks -> Administer a Cluster -> Safely Drain a Node
# https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/
