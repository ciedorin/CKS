#!/bin/bash
set -e

COURSE_DIR="/opt/course/16"

echo "Preparing Question 16: TLS Secret"

echo "Generating the certificate and key in $COURSE_DIR ..."
sudo mkdir -p "$COURSE_DIR"
if [[ ! -f "$COURSE_DIR/clever-cactus.crt" ]]; then
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$COURSE_DIR/clever-cactus.key" \
    -out "$COURSE_DIR/clever-cactus.crt" \
    -subj "/CN=clever-cactus.k8s.local" \
    -addext "subjectAltName=DNS:clever-cactus.k8s.local" >/dev/null 2>&1
fi
sudo chmod a+r "$COURSE_DIR/clever-cactus.crt" "$COURSE_DIR/clever-cactus.key"

echo "Creating namespace clever-cactus..."
kubectl create namespace clever-cactus --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Deployment clever-cactus (it already expects the Secret)..."
kubectl apply -n clever-cactus -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: clever-cactus
  namespace: clever-cactus
  labels:
    app: clever-cactus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: clever-cactus
  template:
    metadata:
      labels:
        app: clever-cactus
    spec:
      containers:
      - name: clever-cactus
        image: nginx:1.25-alpine
        ports:
        - containerPort: 443
        volumeMounts:
        - name: tls
          mountPath: /etc/nginx/tls
          readOnly: true
      volumes:
      - name: tls
        secret:
          secretName: clever-cactus
EOF

sleep 5
echo ""
echo "Current state (the pod cannot start, the Secret is missing):"
kubectl get pods -n clever-cactus 2>/dev/null || true

echo ""
echo "[OK] Question 16 lab setup complete."
echo "   - Namespace: clever-cactus"
echo "   - Deployment: clever-cactus (mounts the Secret 'clever-cactus')"
echo "   - Certificate: $COURSE_DIR/clever-cactus.crt"
echo "   - Key:         $COURSE_DIR/clever-cactus.key"
