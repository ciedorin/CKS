#!/bin/bash
set -e

echo "Preparing Question 14: Docker daemon hardening"

# ---------------------------------------------------------------
# 1. Docker has to be installed
# ---------------------------------------------------------------
if ! command -v dockerd >/dev/null 2>&1; then
  echo "Docker is not installed - installing docker.io ..."
  sudo apt-get update -q
  sudo apt-get install -y docker.io
fi

BACKUP_DIR="/opt/cks-backups"
sudo mkdir -p "$BACKUP_DIR"
if [[ -f /etc/docker/daemon.json && ! -f "$BACKUP_DIR/docker-daemon.json.orig" ]]; then
  sudo cp /etc/docker/daemon.json "$BACKUP_DIR/docker-daemon.json.orig"
fi

# ---------------------------------------------------------------
# 2. The user and the docker group
# ---------------------------------------------------------------
echo "Creating the group docker and the user developer..."
sudo groupadd -f docker
if ! id developer >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash developer
fi
echo "Adding developer to the docker group (this is one of the problems)..."
sudo usermod -aG docker developer

# ---------------------------------------------------------------
# 3. A deliberately insecure daemon configuration
# ---------------------------------------------------------------
echo "Writing an insecure /etc/docker/daemon.json ..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"],
  "group": "developer"
}
EOF

echo "Adding a systemd drop-in so dockerd honours daemon.json hosts..."
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/cks-override.conf >/dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd
EOF

echo "Restarting docker..."
sudo systemctl daemon-reload
sudo systemctl restart docker || true
sleep 3

echo ""
echo "Current state:"
echo "  developer groups: $(id -nG developer 2>/dev/null)"
echo "  socket owner:     $(stat -c '%U:%G' /var/run/docker.sock 2>/dev/null)"
echo "  listening ports:"
sudo ss -ltnp 2>/dev/null | grep -i docker || echo "    (none reported)"

echo ""
echo "[OK] Question 14 lab setup complete."
echo "   - user developer is in the docker group"
echo "   - the docker socket is group owned by 'developer'"
echo "   - dockerd listens on tcp://0.0.0.0:2375"
