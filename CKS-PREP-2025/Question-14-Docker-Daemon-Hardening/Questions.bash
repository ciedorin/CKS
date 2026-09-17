# Question 14 - Docker daemon hardening

# Context:
# A node runs a Docker daemon that was configured carelessly:
#   - the user "developer" was added to the docker group, which is equivalent to
#     giving that user root on the node
#   - the docker socket is group owned by "developer"
#   - the daemon listens on an unauthenticated TCP port

# Task:
# 1. Remove the user "developer" from the docker group
#
# 2. Reconfigure and restart Docker so that the socket file
#    /var/run/docker.sock is owned by the group "root"
#
# 3. Reconfigure and restart Docker so that it does NOT listen on any TCP port
#
# Docker must still be running and usable through the unix socket afterwards.

# Verify:
#   id -nG developer
#   stat -c '%U:%G' /var/run/docker.sock
#   sudo ss -ltnp | grep dockerd
#   sudo docker info

# Documentation Reference
# Docker - daemon configuration file
# https://docs.docker.com/reference/cli/dockerd/#daemon-configuration-file
# Docker - protect the Docker daemon socket
# https://docs.docker.com/engine/security/protect-access/
# CIS Docker Benchmark: 2.x host configuration / daemon configuration
