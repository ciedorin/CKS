# Question 12 - SBOM

# Context:
# The Deployment "alpine" in the namespace alpine runs three containers, each one
# built on a different Alpine base image.
#
# The image archives (tarballs) of those three images are available at:
#
#   /opt/course/12/archives/image-1.tar
#   /opt/course/12/archives/image-2.tar
#   /opt/course/12/archives/image-3.tar
#
# Security flagged the OpenSSL 1.1 library as end of life: any image that still
# ships the package "libcrypto1.1" must not be used any more.

# Task:
# 1. Find out which of the three images still contains the package libcrypto1.1
# 2. Delete the container that uses that image from the Deployment "alpine"
#    (the other two containers must keep running)
# 3. Generate an SBOM of that image in SPDX JSON format and store it at:
#
#       /opt/course/12/alpine-sbom.json
#
#    Use the image archive from /opt/course/12/archives, not a registry pull.

# Hints:
#   trivy image --input /opt/course/12/archives/image-1.tar
#   trivy sbom --help / trivy image --format spdx-json --help
#   bom generate --help

# Documentation Reference
# Trivy - scanning a container image tarball
# https://trivy.dev/latest/docs/target/container_image/
# Trivy - SBOM generation (SPDX)
# https://trivy.dev/latest/docs/supply-chain/sbom/
# Kubernetes SBOM tool (bom)
# https://github.com/kubernetes-sigs/bom
