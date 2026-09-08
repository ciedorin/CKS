# Question 2 - API server hardening - Solution

# Step 1: edit the static pod manifest of the API server
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml

# Change these three flags in spec.containers[0].command:
#
#     - --anonymous-auth=false
#     - --authorization-mode=Node,RBAC
#     - --enable-admission-plugins=NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount
#
# NOTE: --enable-admission-plugins is a single comma separated list. Append
#       NodeRestriction to whatever is already there, do not drop existing plugins.

# Step 2: the kubelet restarts the static pod automatically. Watch it come back:
sudo crictl ps | grep kube-apiserver
watch kubectl get pods -n kube-system

# If the API server does not come back, look at the container logs:
sudo crictl ps -a | grep kube-apiserver
sudo crictl logs <container-id>
# ...or the kubelet journal:
sudo journalctl -u kubelet -f

# Step 3: remove the dangerous ClusterRoleBinding
kubectl get clusterrolebinding system:anonymous
kubectl delete clusterrolebinding system:anonymous

# Step 4: verify anonymous access is refused
curl -k https://127.0.0.1:6443/api/v1/nodes
# expected: 401 Unauthorized ("Unauthorized")

# And that admission + authorization are what you expect:
grep -E "anonymous-auth|authorization-mode|enable-admission-plugins" \
  /etc/kubernetes/manifests/kube-apiserver.yaml
