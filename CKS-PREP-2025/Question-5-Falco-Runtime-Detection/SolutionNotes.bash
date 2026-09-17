# Question 5 - Falco: misbehaving pod - Solution

# Step 0: find out under which systemd unit Falco runs.
# Modern Falco packages ship one unit per driver, so plain "falco" often does not exist.
systemctl list-units --all 'falco*'
FALCO_UNIT=$(systemctl list-units --state=running 'falco*' --no-legend | awk '{print $1}' | head -1)
echo "falco unit: $FALCO_UNIT"        # e.g. falco-modern-bpf.service

# If nothing is running, start a driver unit by hand:
#   sudo systemctl start falco-modern-bpf     # kernel >= 5.8 with BTF
#   sudo systemctl start falco-bpf
#   sudo systemctl start falco-kmod

# Step 1: look at the Falco alerts and find the /dev/mem read
sudo journalctl -fu "$FALCO_UNIT"
# or, if you do not want to follow:
sudo journalctl -u "$FALCO_UNIT" --no-pager | grep -i "/dev/mem" | tail -5

# The alert line contains the container and pod name, for example:
#   Critical Sensitive device read detected (... container_name=ollama
#   pod=ollama-beta-6d4c8f9b7-xk2lp namespace=ollama ...)

# If the pod name is not in the output, map the container id to a pod:
sudo crictl ps --name ollama
sudo crictl inspect <container-id> | grep -i io.kubernetes.pod.name

# Step 2: find the Deployment that owns that pod
kubectl get pods -n ollama -o wide
kubectl -n ollama get pod <pod-name> -o jsonpath='{.metadata.ownerReferences[0].name}'   # the ReplicaSet
kubectl -n ollama get rs <replicaset-name> -o jsonpath='{.metadata.ownerReferences[0].name}'  # the Deployment

# Step 3: scale that Deployment to zero
kubectl scale deployment -n ollama <deployment-name> --replicas=0

# Step 4: verify - the offending deployment has 0 replicas, the others still run
kubectl get deployments -n ollama
kubectl get pods -n ollama

# The Falco alerts should stop once the pod is gone.
