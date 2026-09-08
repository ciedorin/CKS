#!/bin/bash
set -e

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
BACKUP_DIR="/opt/cks-backups"
BACKUP="$BACKUP_DIR/kube-apiserver.yaml.orig"

echo "Preparing Question 2: API server hardening"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found. This lab must run on a kubeadm control plane node." >&2
  exit 1
fi

echo "Backing up the original API server manifest to $BACKUP ..."
sudo mkdir -p "$BACKUP_DIR"
[[ -f "$BACKUP" ]] || sudo cp "$MANIFEST" "$BACKUP"

echo "Weakening the API server configuration ..."
sudo python3 - <<'PY'
import re

path = "/etc/kubernetes/manifests/kube-apiserver.yaml"
with open(path) as f:
    lines = f.read().split("\n")

out = []
seen = {"anonymous": False, "authz": False, "admission": False}
indent = "    "

for line in lines:
    stripped = line.strip()
    if stripped.startswith("- --anonymous-auth="):
        indent = line[: len(line) - len(line.lstrip())]
        out.append(indent + "- --anonymous-auth=true")
        seen["anonymous"] = True
        continue
    if stripped.startswith("- --authorization-mode="):
        indent = line[: len(line) - len(line.lstrip())]
        out.append(indent + "- --authorization-mode=AlwaysAllow")
        seen["authz"] = True
        continue
    if stripped.startswith("- --enable-admission-plugins="):
        indent = line[: len(line) - len(line.lstrip())]
        out.append(indent + "- --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount")
        seen["admission"] = True
        continue
    out.append(line)

# insert any missing flags right after the "- kube-apiserver" command entry
extra = []
if not seen["anonymous"]:
    extra.append(indent + "- --anonymous-auth=true")
if not seen["authz"]:
    extra.append(indent + "- --authorization-mode=AlwaysAllow")
if not seen["admission"]:
    extra.append(indent + "- --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount")

if extra:
    for i, line in enumerate(out):
        if line.strip() == "- kube-apiserver":
            out[i + 1 : i + 1] = extra
            break

with open(path, "w") as f:
    f.write("\n".join(out))
PY

echo "Waiting for the API server to restart with the new configuration..."
for i in $(seq 1 60); do
  if kubectl get --raw /healthz >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

echo "Granting cluster-admin to system:anonymous (this is the misconfiguration to remove)..."
kubectl create clusterrolebinding system:anonymous \
  --clusterrole=cluster-admin \
  --user=system:anonymous \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "[OK] Question 2 lab setup complete."
echo "   - API server manifest: $MANIFEST (weakened)"
echo "   - ClusterRoleBinding system:anonymous created"
echo "   - original backup: $BACKUP"
