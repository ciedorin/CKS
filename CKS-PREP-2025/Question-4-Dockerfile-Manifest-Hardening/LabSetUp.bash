#!/bin/bash
set -e

APP_DIR="/home/candidate/app"

echo "Preparing Question 4: Dockerfile and manifest hardening"

sudo mkdir -p "$APP_DIR"

echo "Writing $APP_DIR/Dockerfile ..."
sudo tee "$APP_DIR/Dockerfile" >/dev/null <<'EOF'
FROM alpine:3.20

RUN apk add --no-cache curl

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER root

EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
EOF

echo "Writing $APP_DIR/entrypoint.sh ..."
sudo tee "$APP_DIR/entrypoint.sh" >/dev/null <<'EOF'
#!/bin/sh
while true; do sleep 3600; done
EOF

echo "Writing $APP_DIR/deployment.yaml ..."
sudo tee "$APP_DIR/deployment.yaml" >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: couch-app
  namespace: couch
  labels:
    app: couch-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: couch-app
  template:
    metadata:
      labels:
        app: couch-app
    spec:
      containers:
      - name: couch-app
        image: registry.local/couch-app:1.0
        ports:
        - containerPort: 8080
        securityContext:
          privileged: true
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsUser: 10001
EOF

sudo chmod -R a+rw "$APP_DIR"

echo ""
echo "[OK] Question 4 lab setup complete."
echo "   - $APP_DIR/Dockerfile"
echo "   - $APP_DIR/deployment.yaml"
