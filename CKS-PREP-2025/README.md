# CKS Practice (Simple Edition)

Straightforward CKS (Certified Kubernetes Security Specialist) practice labs. Every question lives in its own folder with bash files:

**Note:** This is a living repo and may still contain bugs or rough edges. If you spot an issue—especially in lab setup or validation scripts—please open an issue or PR so it can be fixed.

**Exam prep note:** These questions are designed to be similar to the CKS exam, but they are not meant to be exact matches. Learn the underlying concepts in depth and try different scenarios so you can solve variations under exam conditions.

- `LabSetUp.bash` — set up the environment for the question.
- `Questions.bash` — the scenario text plus documentation references.
- `SolutionNotes.bash` — a step-by-step solution when you need a hint.
- `validate.bash` — automatic validation checks to confirm your solution is correct.
- `cleanup.bash` — clean up and remove resources created during the question.

---

## How to Use

1. Launch the [Killercoda CKS playground](https://killercoda.com/killer-shell-cks) or your own cluster.
2. Clone this repo inside the environment:
   ```bash
   git clone <your-repo-url> ~/CKS-PREP-2025
   cd ~/CKS-PREP-2025
   ```
3. Run a question setup by number:
   ```bash
   scripts/run-question.sh 5
   ```
4. Work through the task, then consult `SolutionNotes.bash` if you need help.
5. Validate your solution:
   ```bash
   scripts/validate-question.sh 5
   ```
6. Clean up resources when done:
   ```bash
   scripts/cleanup-question.sh 5
   ```

---

## Validating Your Solutions

Each question has a `validate.bash` script that runs automated checks against your cluster to confirm the solution is correct.

### Validate a single question
```bash
# By question number
scripts/validate-question.sh 5

# By directory name
scripts/validate-question.sh Question-5-Falco
```

### Validate all questions
```bash
scripts/validate-question.sh all
```

The script outputs `PASS` or `FAIL` for each check, with a final score summary. Exit code is `0` if all checks pass, non-zero otherwise.

---

## Simulated Exam Desktop (VSCodium)

You can use **VSCodium** (an open-source VS Code build) inside the Killercoda simulated desktop to edit files in a familiar IDE environment, similar to what is available in the real exam.

> **NOTE: A paid Killercoda subscription is required** for the simulated desktop environment.
> Without it, the desktop GUI is not available and VSCodium cannot be launched graphically.

### Install VSCodium
```bash
scripts/install-codium.sh
```

### Launch VSCodium
Once installed, open it from inside your repo:
```bash
cd ~/CKS-PREP-2025
codium --no-sandbox --user-data-dir .
```

This opens VSCodium in the current directory, allowing you to browse and edit all question files directly.

---

## Available Questions

| # | Topic | Focus area |
|---|-------|------------|
| 1 | CIS Benchmark - kubelet | Cluster hardening, kube-bench 4.2.x controls |
| 2 | API Server hardening | Anonymous auth, Node,RBAC, NodeRestriction |
| 3 | ImagePolicyWebhook | Admission control, fail closed on unsigned images |
| 4 | Dockerfile & manifest hardening | Supply chain, least privilege, one-line fixes |
| 5 | Falco - runtime detection | Find the pod reading /dev/mem, scale it to zero |
| 6 | Container immutability | runAsUser, read-only rootfs, no privilege escalation |
| 7 | Audit logging | Audit policy + kube-apiserver audit flags |
| 8 | NetworkPolicies | Deny all ingress, allow only from one namespace |
| 9 | Ingress with TLS | TLS termination + HTTP to HTTPS redirect |
| 10 | ServiceAccount token | Disable automount, projected token volume |
| 11 | Node upgrade | kubeadm upgrade node, drain / uncordon |
| 12 | SBOM | Find the vulnerable image, generate an SPDX JSON SBOM |
| 13 | Pod Security Standards | Make a workload comply with "restricted" |
| 14 | Docker daemon hardening | docker group, socket ownership, no TCP listener |
| 15 | Istio mTLS | Sidecar injection + PeerAuthentication STRICT |
| 16 | TLS Secret | kubectl create secret tls |

---

## Notes and requirements

Some questions change the control plane or the node itself. They always back up
what they touch to `/opt/cks-backups/` and their `cleanup.bash` restores it.

| Question | Needs |
|---|---|
| 1, 2, 3, 7 | a kubeadm control plane node (edits static pod manifests / kubelet config) |
| 1 | kube-bench (downloaded and installed by `LabSetUp.bash` if missing) |
| 5 | Falco (installed and started by `LabSetUp.bash` if missing; the unit is usually `falco-modern-bpf`) |
| 9 | an ingress-nginx controller (installed by `LabSetUp.bash` if missing) |
| 11 | a multi node cluster (control plane + at least one worker) |
| 12 | `docker` or `ctr` to export image archives, plus `trivy` (or `bom`) |
| 14 | Docker (installed by `LabSetUp.bash` if missing) |
| 15 | internet access for istioctl and the Istio images, a schedulable (untainted) node, and roughly 1 GB free memory for istiod |

Questions 8 and 9 both use the namespace `prod`. Run the cleanup of one before
setting up the other.
