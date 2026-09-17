#!/bin/bash
set -e

echo "Preparing Question 6: Container immutability"

echo "Creating namespace lamp..."
kubectl create namespace lamp --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Deployment lamp-deployment..."
kubectl apply -n lamp -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lamp-deployment
  namespace: lamp
  labels:
    app: lamp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lamp
  template:
    metadata:
      labels:
        app: lamp
    spec:
      containers:
      - name: apache
        image: busybox:1.36
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
        ports:
        - containerPort: 80
      - name: mysql
        image: busybox:1.36
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
        ports:
        - containerPort: 3306
EOF

echo "Waiting for the deployment to become available..."
kubectl wait --for=condition=Available --timeout=120s deployment/lamp-deployment -n lamp || true

echo ""
echo "[OK] Question 6 lab setup complete."
echo "   - Namespace: lamp"
echo "   - Deployment: lamp-deployment (containers: apache, mysql)"
echo "   - No securityContext is configured yet."
