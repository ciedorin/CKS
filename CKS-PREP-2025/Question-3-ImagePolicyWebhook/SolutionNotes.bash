# Question 3 - ImagePolicyWebhook - Solution

# Step 1: complete the admission configuration file
sudo vim /etc/kubernetes/admission/config.yaml

# Final content:
cat <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/admission/kubeconf.yaml
      allowTTL: 50
      denyTTL: 50
      retryBackoff: 500
      defaultAllow: false
EOF

# Step 2 + 3 + 4: edit the API server static pod manifest
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml

# 2) add ImagePolicyWebhook to the existing plugin list:
#     - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
#
# 3) add the admission control config file flag:
#     - --admission-control-config-file=/etc/kubernetes/admission/config.yaml
#
# 4) mount the directory into the static pod:
#
#    spec.containers[0].volumeMounts:
#      - name: admission
#        mountPath: /etc/kubernetes/admission
#        readOnly: true
#
#    spec.volumes:
#      - name: admission
#        hostPath:
#          path: /etc/kubernetes/admission
#          type: DirectoryOrCreate

# Step 3: wait for the API server to restart
sudo crictl ps | grep kube-apiserver
kubectl get --raw /healthz

# Troubleshooting - if the API server never comes back:
sudo crictl ps -a | grep kube-apiserver
sudo crictl logs <container-id>
sudo journalctl -u kubelet -f

# Step 4: prove that images are now rejected (fail closed)
kubectl run test-image --image=nginx
# expected: Error from server (Forbidden): pods "test-image" is forbidden:
#           ... failed to call webhook ... / images not allowed
