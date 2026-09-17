# Question 12 - SBOM - Solution

# Step 1: find the image that still ships libcrypto1.1
for f in /opt/course/12/archives/*.tar; do
  echo "== $f"
  trivy image --quiet --input "$f" --scanners vuln --format table 2>/dev/null | head -5
done

# A direct search for the package is faster:
for f in /opt/course/12/archives/*.tar; do
  echo -n "$f -> "
  trivy image --quiet --input "$f" --list-all-pkgs --format json 2>/dev/null \
    | grep -c "libcrypto1.1"
done

# The hit is the alpine:3.14 image (Alpine 3.14 ships OpenSSL 1.1,
# Alpine 3.17 and 3.20 ship libcrypto3).

kubectl get deployment alpine -n alpine \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{" -> "}{.image}{"\n"}{end}'
# cache   -> alpine:3.17
# worker  -> alpine:3.14      <-- this one
# sidecar -> alpine:3.20

# Step 2: remove that container from the Deployment
kubectl edit deployment alpine -n alpine
# delete the whole "- name: worker" block from spec.template.spec.containers

kubectl rollout status deployment alpine -n alpine
kubectl get deployment alpine -n alpine \
  -o jsonpath='{.spec.template.spec.containers[*].name}{"\n"}'

# Step 3: generate the SPDX JSON SBOM of that image from its archive
trivy image --input /opt/course/12/archives/image-2.tar \
  --format spdx-json \
  --output /opt/course/12/alpine-sbom.json

# Alternative with the Kubernetes bom tool:
#   bom generate --image-archive /opt/course/12/archives/image-2.tar \
#     --format json --output /opt/course/12/alpine-sbom.json

# Verify the SBOM
head -c 400 /opt/course/12/alpine-sbom.json
grep -o '"spdxVersion":"[^"]*"' /opt/course/12/alpine-sbom.json
grep -c libcrypto1.1 /opt/course/12/alpine-sbom.json
