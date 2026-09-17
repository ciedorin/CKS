#!/bin/bash
set -e

echo "Preparing Question 11: Node upgrade"

echo ""
echo "Current cluster state:"
kubectl get nodes -o wide

CP_NODE=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
CP_VERSION=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null || true)

echo ""
echo "Control plane node:    ${CP_NODE:-<none found>}"
echo "Control plane version: ${CP_VERSION:-<unknown>}"

WORKERS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $1}' | grep -v "^${CP_NODE}$" || true)

if [[ -z "$WORKERS" ]]; then
  echo ""
  echo "WARNING: this cluster has no worker node."
  echo "         This question needs a multi node cluster (control plane + at least one worker)."
  echo "         On Killercoda use a two node playground."
else
  echo ""
  echo "Worker nodes and their kubelet versions:"
  for w in $WORKERS; do
    V=$(kubectl get node "$w" -o jsonpath='{.status.nodeInfo.kubeletVersion}')
    echo "  $w -> $V"
  done
fi

echo ""
echo "[OK] Question 11 lab setup complete."
echo "   NOTE: a version skew cannot be created artificially by this script."
echo "         Work with whatever skew the cluster has: the goal is that every"
echo "         node runs the same version as the control plane, is Ready and"
echo "         is schedulable."
