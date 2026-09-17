# Question 1 - CIS Benchmark (kubelet) - Solution

# Step 1: run the benchmark and look at the kubelet section
sudo kube-bench run --targets node

# Only the failures:
sudo kube-bench run --targets node | grep -E '^\[(FAIL|WARN)\]'

# Only the four controls of this task:
sudo kube-bench run --targets node --check 4.2.1,4.2.2,4.2.4,4.2.5

# Expected before the fix:
#   [FAIL] 4.2.1 Ensure that the --anonymous-auth argument is set to false
#   [FAIL] 4.2.2 Ensure that the --authorization-mode argument is not set to AlwaysAllow
#   [FAIL] 4.2.4 Verify that the --read-only-port argument is set to 0
#   [FAIL] 4.2.5 Ensure that the --streaming-connection-idle-timeout argument is not set to 0
#
# kube-bench also prints a remediation block telling you exactly which key to set
# in the kubelet config file. Read it - that is the whole point of the tool.

# Step 2: edit the kubelet configuration file
sudo vim /var/lib/kubelet/config.yaml

# authentication:
#   anonymous:
#     enabled: false            <-- was true          (4.2.1)
# authorization:
#   mode: Webhook               <-- was AlwaysAllow   (4.2.2)
# readOnlyPort: 0               <-- was 10255         (4.2.4)
# streamingConnectionIdleTimeout: 4h0m0s   <-- was 0  (4.2.5)

# The same with sed (edit by hand in the exam, this is only for reference):
sudo sed -i 's/^readOnlyPort: .*/readOnlyPort: 0/' /var/lib/kubelet/config.yaml
sudo sed -i 's/^streamingConnectionIdleTimeout: .*/streamingConnectionIdleTimeout: 4h0m0s/' /var/lib/kubelet/config.yaml

# Restart the kubelet so the configuration is picked up
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet
kubectl get nodes                       # must be Ready again

# Step 3: run the benchmark again - the four controls must now be PASS
sudo kube-bench run --targets node --check 4.2.1,4.2.2,4.2.4,4.2.5

# Extra proof that the read-only port is really gone:
curl -s http://localhost:10255/pods     # must fail to connect
sudo ss -ltn | grep 10255               # no output
