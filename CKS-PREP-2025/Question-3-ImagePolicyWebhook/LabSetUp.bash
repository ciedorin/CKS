#!/bin/bash
set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
ADMISSION_DIR="/etc/kubernetes/admission"
BACKUP_DIR="/opt/cks-backups"
BACKUP="$BACKUP_DIR/kube-apiserver.yaml.q3-orig"

echo "Preparing Question 3: ImagePolicyWebhook"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found. This lab must run on a kubeadm control plane node." >&2
  exit 1
fi

echo "Backing up the original API server manifest to $BACKUP ..."
sudo mkdir -p "$BACKUP_DIR"
[[ -f "$BACKUP" ]] || sudo cp "$MANIFEST" "$BACKUP"

echo "Creating the admission directory $ADMISSION_DIR ..."
sudo mkdir -p "$ADMISSION_DIR"

echo "Generating client credentials for the image policy webhook..."
if [[ ! -f "$ADMISSION_DIR/webhook.crt" ]]; then
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$ADMISSION_DIR/webhook.key" \
    -out "$ADMISSION_DIR/webhook.crt" \
    -subj "/CN=image-policy-webhook-client" >/dev/null 2>&1
fi

echo "Writing the webhook kubeconfig..."
sudo tee "$ADMISSION_DIR/kubeconf.yaml" >/dev/null <<'EOF'
apiVersion: v1
kind: Config
clusters:
- name: image-policy-webhook
  cluster:
    certificate-authority: /etc/kubernetes/admission/webhook.crt
    server: https://image-policy-webhook.local:8081/image-policy
contexts:
- name: image-policy-webhook
  context:
    cluster: image-policy-webhook
    user: api-server
current-context: image-policy-webhook
preferences: {}
users:
- name: api-server
  user:
    client-certificate: /etc/kubernetes/admission/webhook.crt
    client-key: /etc/kubernetes/admission/webhook.key
EOF

echo "Writing an INCOMPLETE admission configuration (this is what you have to fix)..."
sudo tee "$ADMISSION_DIR/config.yaml" >/dev/null <<'EOF'
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins: []
EOF

sudo chmod 600 "$ADMISSION_DIR/webhook.key"

echo ""
echo "[OK] Question 3 lab setup complete."
echo "   - admission directory:  $ADMISSION_DIR"
echo "   - webhook kubeconfig:   $ADMISSION_DIR/kubeconf.yaml"
echo "   - admission config:     $ADMISSION_DIR/config.yaml  (incomplete)"
echo "   - API server backup:    $BACKUP"
