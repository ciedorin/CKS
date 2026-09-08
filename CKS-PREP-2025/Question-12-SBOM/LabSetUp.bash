#!/bin/bash
set -e

COURSE_DIR="/opt/course/12"
ARCHIVE_DIR="$COURSE_DIR/archives"

echo "Preparing Question 12: SBOM"

sudo mkdir -p "$ARCHIVE_DIR"

IMAGES=(alpine:3.17 alpine:3.14 alpine:3.20)
FILES=(image-1.tar image-2.tar image-3.tar)

echo "Exporting the container image archives to $ARCHIVE_DIR ..."
for i in 0 1 2; do
  IMG="${IMAGES[$i]}"
  OUT="$ARCHIVE_DIR/${FILES[$i]}"
  if [[ -f "$OUT" ]]; then
    echo "  $OUT already present, skipping"
    continue
  fi
  if command -v docker >/dev/null 2>&1; then
    sudo docker pull "$IMG" >/dev/null
    sudo docker save "$IMG" -o "$OUT"
  elif command -v ctr >/dev/null 2>&1; then
    sudo ctr -n k8s.io images pull "docker.io/library/$IMG" >/dev/null
    sudo ctr -n k8s.io images export "$OUT" "docker.io/library/$IMG"
  else
    echo "  WARNING: neither docker nor ctr is available - cannot export $IMG"
  fi
done
sudo chmod -R a+r "$COURSE_DIR" 2>/dev/null || true

if ! command -v trivy >/dev/null 2>&1 && ! command -v bom >/dev/null 2>&1; then
  echo ""
  echo "WARNING: neither trivy nor bom is installed. Install one of them, e.g.:"
  echo "  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin"
fi

echo "Creating namespace alpine..."
kubectl create namespace alpine --dry-run=client -o yaml | kubectl apply -f -

echo "Creating Deployment alpine with three containers..."
kubectl apply -n alpine -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alpine
  namespace: alpine
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alpine
  template:
    metadata:
      labels:
        app: alpine
    spec:
      containers:
      - name: cache
        image: alpine:3.17
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
      - name: worker
        image: alpine:3.14
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
      - name: sidecar
        image: alpine:3.20
        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
EOF

kubectl wait --for=condition=Available --timeout=180s deployment/alpine -n alpine || true

echo ""
echo "[OK] Question 12 lab setup complete."
echo "   - Namespace: alpine, Deployment: alpine (containers: cache, worker, sidecar)"
echo "   - Image archives: $ARCHIVE_DIR/image-1.tar image-2.tar image-3.tar"
