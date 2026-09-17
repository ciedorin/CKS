# Question 11 - Node upgrade - Solution

# Step 0: find the node and the target version
kubectl get nodes
CP_VERSION=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')
echo "target version: $CP_VERSION"       # e.g. v1.31.1
NODE=node01                              # or compute-0, whatever your cluster reports

# Step 1: drain the node - run this from the CONTROL PLANE
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data

# Step 2..4 run ON THE WORKER NODE
ssh "$NODE"

# 2) upgrade kubeadm to the target version (drop the leading v for apt)
sudo apt update
sudo apt-cache madison kubeadm | head
sudo apt-get install -y --allow-change-held-packages kubeadm=1.31.1-1.1
kubeadm version

# 3) upgrade the node configuration (kubelet config, certs)
sudo kubeadm upgrade node

# 4) upgrade kubelet and kubectl, then restart the kubelet
sudo apt-get install -y --allow-change-held-packages kubelet=1.31.1-1.1 kubectl=1.31.1-1.1
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet

exit    # back to the control plane

# Step 5: put the node back into service
kubectl uncordon "$NODE"

# Verify
kubectl get nodes -o wide        # same version everywhere, all Ready, none SchedulingDisabled

# If the apt repository does not have the version, the repo may still point at the
# old minor release - check /etc/apt/sources.list.d/kubernetes.list and update the
# v1.xx in the URL first.
