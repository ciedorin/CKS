#!/bin/bash
# Lab setup for Question 2 - API server hardening
#
# NOTE: no "set -e" on purpose - if the API server does not come back we want to
#       roll the manifest back instead of leaving a broken cluster behind.
set -uo pipefail

MANIFEST="/etc/kubernetes/manifests/kube-apiserver.yaml"
BACKUP_DIR="/opt/cks-backups"
BACKUP="$BACKUP_DIR/kube-apiserver.yaml.orig"
WAIT_SECONDS="${WAIT_SECONDS:-240}"

echo "Preparing Question 2: API server hardening"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found. This lab must run on a kubeadm control plane node." >&2
  exit 1
fi

wait_for_api() {
  local deadline=$((SECONDS + $1))
  while (( SECONDS < deadline )); do
    if kubectl get --raw /healthz >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

show_diagnostics() {
  echo ""
  echo "---------- kube-apiserver container state ----------"
  sudo crictl ps -a --name kube-apiserver 2>/dev/null | head -5
  local cid
  cid=$(sudo crictl ps -a --name kube-apiserver -q 2>/dev/null | head -1)
  if [[ -n "$cid" ]]; then
    echo "---------- last 30 log lines ----------"
    sudo crictl logs --tail 30 "$cid" 2>&1 | tail -30
  fi
  echo "---------- kubelet journal ----------"
  sudo journalctl -u kubelet --no-pager -n 20 2>/dev/null | tail -20
  echo "---------------------------------------"
}

# ---------------------------------------------------------------
# 0. The cluster has to be healthy before we break anything
# ---------------------------------------------------------------
echo "Checking that the API server is reachable..."
if ! wait_for_api 60; then
  echo "ERROR: the API server is not reachable right now." >&2
  echo "       Fix the cluster first, then re-run this setup." >&2
  if [[ -f "$BACKUP" ]]; then
    echo "       A backup from a previous run exists - restore it with:" >&2
    echo "         sudo cp $BACKUP $MANIFEST" >&2
  fi
  exit 1
fi

# ---------------------------------------------------------------
# 1. Create the bad ClusterRoleBinding FIRST, while the API works
# ---------------------------------------------------------------
echo "Granting cluster-admin to system:anonymous (this is the misconfiguration to remove)..."
if ! kubectl get clusterrolebinding system:anonymous >/dev/null 2>&1; then
  kubectl create clusterrolebinding system:anonymous \
    --clusterrole=cluster-admin \
    --user=system:anonymous
fi

# ---------------------------------------------------------------
# 2. Back up the manifest
# ---------------------------------------------------------------
echo "Backing up the original API server manifest to $BACKUP ..."
sudo mkdir -p "$BACKUP_DIR"
[[ -f "$BACKUP" ]] || sudo cp "$MANIFEST" "$BACKUP"

# ---------------------------------------------------------------
# 3. Build the weakened manifest in a temp file, then move it in
# ---------------------------------------------------------------
TMP_MANIFEST="$(mktemp /tmp/kube-apiserver.XXXXXX.yaml)"

echo "Weakening the API server configuration ..."
sudo python3 - "$MANIFEST" "$TMP_MANIFEST" <<'PY'
import sys

src, dst = sys.argv[1], sys.argv[2]

with open(src) as f:
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

extra = []
if not seen["anonymous"]:
    extra.append(indent + "- --anonymous-auth=true")
if not seen["authz"]:
    extra.append(indent + "- --authorization-mode=AlwaysAllow")
if not seen["admission"]:
    extra.append(indent + "- --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount")

if extra:
    inserted = False
    for i, line in enumerate(out):
        if line.strip() == "- kube-apiserver":
            out[i + 1 : i + 1] = extra
            inserted = True
            break
    if not inserted:
        print("ERROR: could not find the '- kube-apiserver' command entry", file=sys.stderr)
        sys.exit(1)

text = "\n".join(out)

# sanity check the result before it is handed to the kubelet
try:
    import yaml
    doc = yaml.safe_load(text)
    cmd = doc["spec"]["containers"][0]["command"]
    assert any(str(a).startswith("--anonymous-auth=") for a in cmd)
    assert any(str(a).startswith("--authorization-mode=") for a in cmd)
except ImportError:
    pass          # no pyyaml on this node - skip the structural check
except Exception as exc:
    print("ERROR: the generated manifest is not valid: %s" % exc, file=sys.stderr)
    sys.exit(1)

with open(dst, "w") as f:
    f.write(text)
PY

if [[ $? -ne 0 || ! -s "$TMP_MANIFEST" ]]; then
  echo "ERROR: could not generate the weakened manifest - nothing was changed." >&2
  rm -f "$TMP_MANIFEST"
  exit 1
fi

sudo cp "$TMP_MANIFEST" "$MANIFEST"
rm -f "$TMP_MANIFEST"

# ---------------------------------------------------------------
# 4. Wait for the API server, roll back if it does not come back
# ---------------------------------------------------------------
echo "Waiting up to ${WAIT_SECONDS}s for the API server to restart..."
if ! wait_for_api "$WAIT_SECONDS"; then
  echo ""
  echo "ERROR: the API server did not come back after the change." >&2
  show_diagnostics
  echo "Rolling the manifest back to $BACKUP ..." >&2
  sudo cp "$BACKUP" "$MANIFEST"
  if wait_for_api 180; then
    echo "The cluster is healthy again. The lab was NOT set up." >&2
  else
    echo "The API server is still down. Restore it by hand:" >&2
    echo "  sudo cp $BACKUP $MANIFEST" >&2
  fi
  exit 1
fi

echo ""
echo "[OK] Question 2 lab setup complete."
echo "   - API server manifest: $MANIFEST (weakened)"
echo "   - ClusterRoleBinding system:anonymous created"
echo "   - original backup: $BACKUP"
