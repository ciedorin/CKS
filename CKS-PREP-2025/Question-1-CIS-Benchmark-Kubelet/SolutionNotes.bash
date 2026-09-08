# Question 1 - CIS Benchmark (kubelet) - Solution

# Step 0 (optional): see what a benchmark tool reports
kube-bench run --targets node          # look for the 4.2.x FAIL entries

# Step 1: edit the kubelet configuration file
sudo vim /var/lib/kubelet/config.yaml

# Make the following changes:
#
# authentication:
#   anonymous:
#     enabled: false            <-- was true          (CIS 4.2.1)
# authorization:
#   mode: Webhook               <-- was AlwaysAllow   (CIS 4.2.2)
# readOnlyPort: 0               <-- was 10255         (CIS 4.2.4)
# streamingConnectionIdleTimeout: 4h0m0s   <-- was 0  (CIS 4.2.5)

# The same result with sed (edit by hand in the exam, this is only for reference):
sudo sed -i 's/^readOnlyPort: .*/readOnlyPort: 0/' /var/lib/kubelet/config.yaml
sudo sed -i 's/^streamingConnectionIdleTimeout: .*/streamingConnectionIdleTimeout: 4h0m0s/' /var/lib/kubelet/config.yaml

# Step 2: restart the kubelet so the configuration is picked up
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet

# Step 3: verify
kubectl get nodes                                    # node must be Ready
sudo grep -A2 'anonymous:' /var/lib/kubelet/config.yaml
sudo grep -A2 '^authorization:' /var/lib/kubelet/config.yaml
sudo grep -E '^(readOnlyPort|streamingConnectionIdleTimeout):' /var/lib/kubelet/config.yaml

# The read-only port must no longer answer:
curl -s http://localhost:10255/pods    # should fail to connect
