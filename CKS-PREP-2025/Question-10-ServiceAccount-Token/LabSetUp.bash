#!/bin/bash
set -e

echo "Preparing Question 10: ServiceAccount token"

echo "Creating namespace monitoring..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "Creating ServiceAccount stats-monitor-sa (API credentials are auto mounted)..."
kubectl apply -n monitoring -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: stats-monitor-sa
  namespace: monitoring
automountServiceAccountToken: true
EOF

echo "Creating Deployment stats-monitor..."
kubectl apply -n monitoring -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stats-monitor
  namespace: monitoring
  labels:
    app: stats-monitor
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stats-monitor
  template:
    metadata:
      labels:
        app: stats-monitor
    spec:
      serviceAccountName: stats-monitor-sa
      containers:
      - name: stats-monitor
        image: busybox:1.36
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
EOF

kubectl wait --for=condition=Available --timeout=120s deployment/stats-monitor -n monitoring || true

echo ""
echo "[OK] Question 10 lab setup complete."
echo "   - Namespace: monitoring"
echo "   - ServiceAccount: stats-monitor-sa (automountServiceAccountToken: true)"
echo "   - Deployment: stats-monitor"
