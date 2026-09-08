#!/bin/bash
set -e

echo "Preparing Question 8: NetworkPolicies"

echo "Creating namespaces prod, data and other..."
for ns in prod data other; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

echo "Labelling namespace prod with env=prod..."
kubectl label namespace prod env=prod --overwrite

echo "Deploying the prod workloads..."
kubectl apply -n prod -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: prod
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
      - name: curl
        image: curlimages/curl:8.9.1
        command: ["sleep", "infinity"]
EOF

echo "Deploying the data workloads..."
kubectl apply -n data -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: data
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: data
spec:
  selector:
    app: db
  ports:
  - port: 80
    targetPort: 80
EOF

echo "Deploying an out-of-scope client in namespace other..."
kubectl apply -n other -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: intruder
  namespace: other
spec:
  replicas: 1
  selector:
    matchLabels:
      app: intruder
  template:
    metadata:
      labels:
        app: intruder
    spec:
      containers:
      - name: curl
        image: curlimages/curl:8.9.1
        command: ["sleep", "infinity"]
EOF

echo "Waiting for the workloads..."
kubectl wait --for=condition=Available --timeout=120s deployment -n prod --all || true
kubectl wait --for=condition=Available --timeout=120s deployment -n data --all || true
kubectl wait --for=condition=Available --timeout=120s deployment -n other --all || true

echo ""
echo "[OK] Question 8 lab setup complete."
echo "   - Namespace prod  (label env=prod): Deployment web + Service web, Deployment client"
echo "   - Namespace data: Deployment db + Service db"
echo "   - Namespace other: Deployment intruder"
echo "   - No NetworkPolicies exist yet."
