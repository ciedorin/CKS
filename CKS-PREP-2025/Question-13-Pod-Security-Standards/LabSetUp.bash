#!/bin/bash
set -e

echo "Preparing Question 13: Pod Security Standards"

echo "Creating namespace confidential with the restricted Pod Security Standard enforced..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: confidential
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

echo "Creating the non compliant Deployment confidential-app..."
kubectl apply -n confidential -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: confidential-app
  namespace: confidential
  labels:
    app: confidential-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: confidential-app
  template:
    metadata:
      labels:
        app: confidential-app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
EOF

echo "Waiting a few seconds for the ReplicaSet to report the violation..."
sleep 5

echo ""
echo "Current state (the pods cannot be created):"
kubectl get deployment,rs,pods -n confidential 2>/dev/null || true
echo ""
echo "The reason is visible in the ReplicaSet events:"
kubectl get events -n confidential --sort-by=.lastTimestamp 2>/dev/null | tail -5 || true

echo ""
echo "[OK] Question 13 lab setup complete."
echo "   - Namespace: confidential (enforce=restricted)"
echo "   - Deployment: confidential-app (not compliant, 0 pods running)"
