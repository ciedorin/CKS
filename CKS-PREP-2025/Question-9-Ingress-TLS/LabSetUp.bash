#!/bin/bash
set -e

echo "Preparing Question 9: Ingress with TLS"

# ---------------------------------------------------------------
# 1. An ingress controller has to exist
# ---------------------------------------------------------------
if ! kubectl get ingressclass nginx >/dev/null 2>&1; then
  echo "No 'nginx' IngressClass found - installing ingress-nginx..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/baremetal/deploy.yaml
  echo "Waiting for the ingress-nginx controller..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=Ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=300s || true
else
  echo "IngressClass 'nginx' already present."
fi

# ---------------------------------------------------------------
# 2. The application
# ---------------------------------------------------------------
echo "Creating namespace prod..."
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

echo "Deploying the web application..."
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
EOF

# ---------------------------------------------------------------
# 3. The TLS certificate
# ---------------------------------------------------------------
echo "Creating the TLS secret web-cert..."
CERT_DIR="$(mktemp -d)"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/tls.key" -out "$CERT_DIR/tls.crt" \
  -subj "/CN=web.k8s.local" \
  -addext "subjectAltName=DNS:web.k8s.local" >/dev/null 2>&1

kubectl create secret tls web-cert -n prod \
  --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
rm -rf "$CERT_DIR"

kubectl wait --for=condition=Available --timeout=120s deployment/web -n prod || true

echo ""
echo "[OK] Question 9 lab setup complete."
echo "   - Namespace: prod"
echo "   - Deployment + Service: web (port 80)"
echo "   - TLS Secret: web-cert (CN=web.k8s.local)"
echo "   - No Ingress exists yet."
