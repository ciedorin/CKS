# Question 7 - Audit logging - Solution

# Step 1: write the audit policy
sudo vim /etc/kubernetes/policy/audit-policy.yaml

cat <<'EOF'
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# a) all namespaces interactions at RequestResponse level
- level: RequestResponse
  resources:
  - group: ""
    resources: ["namespaces"]

# b) the request body of deployments interactions in namespace webapps
- level: Request
  resources:
  - group: "apps"
    resources: ["deployments"]
  namespaces: ["webapps"]

# c) ConfigMap and Secret interactions in all namespaces at Metadata level
- level: Metadata
  resources:
  - group: ""
    resources: ["configmaps", "secrets"]

# d) everything else at Metadata level
- level: Metadata
EOF

# Step 2: enable auditing on the API server
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml

# 2a) add the flags to spec.containers[0].command:
#
#     - --audit-policy-file=/etc/kubernetes/policy/audit-policy.yaml
#     - --audit-log-path=/etc/kubernetes/audit.logs.txt
#     - --audit-log-maxbackup=2
#     - --audit-log-maxage=10
#
# 2b) mount the policy directory and the log file into the static pod:
#
#    spec.containers[0].volumeMounts:
#      - name: audit-policy
#        mountPath: /etc/kubernetes/policy
#        readOnly: true
#      - name: audit-log
#        mountPath: /etc/kubernetes/audit.logs.txt
#
#    spec.volumes:
#      - name: audit-policy
#        hostPath:
#          path: /etc/kubernetes/policy
#          type: DirectoryOrCreate
#      - name: audit-log
#        hostPath:
#          path: /etc/kubernetes/audit.logs.txt
#          type: FileOrCreate

# Step 3: wait for the API server to restart
sudo crictl ps | grep kube-apiserver
kubectl get --raw /healthz

# Troubleshooting:
sudo crictl ps -a | grep kube-apiserver
sudo crictl logs <container-id>
sudo journalctl -u kubelet -f

# Step 4: verify the audit log is being written
kubectl get ns                                   # generate some traffic
sudo tail -2 /etc/kubernetes/audit.logs.txt
sudo grep '"resource":"namespaces"' /etc/kubernetes/audit.logs.txt | tail -1
