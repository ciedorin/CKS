#!/bin/bash
# Validation script for Question 14 - Docker daemon hardening
set -uo pipefail

PASS=0
FAIL=0
TOTAL=0

check() {
  local description="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

echo "============================================"
echo " Validating Question 14: Docker daemon hardening"
echo "============================================"

# 1. the user is no longer in the docker group
check "user 'developer' exists" \
  bash -c 'id developer'

check "user 'developer' is NOT in the docker group" \
  bash -c 'id -nG developer 2>/dev/null | tr " " "\n" | grep -qx "docker" && exit 1 || exit 0'

check "the docker group does not list developer as a member" \
  bash -c 'getent group docker | cut -d: -f4 | tr "," "\n" | grep -qx "developer" && exit 1 || exit 0'

# 2. the socket is group owned by root
check "the docker socket /var/run/docker.sock exists" \
  bash -c 'sudo test -S /var/run/docker.sock'

check "the docker socket is group owned by root" \
  bash -c 'G=$(stat -c "%G" /var/run/docker.sock 2>/dev/null); [[ "$G" == "root" ]]'

check "daemon.json no longer sets the group to developer" \
  bash -c 'sudo test -f /etc/docker/daemon.json || exit 0; sudo grep -q "\"developer\"" /etc/docker/daemon.json && exit 1 || exit 0'

# 3. no TCP listener
check "daemon.json does not configure any tcp:// host" \
  bash -c 'sudo test -f /etc/docker/daemon.json || exit 0; sudo grep -q "tcp://" /etc/docker/daemon.json && exit 1 || exit 0'

check "the systemd unit does not pass a tcp:// host either" \
  bash -c 'sudo systemctl cat docker 2>/dev/null | grep -E "^ExecStart" | grep -q "tcp://" && exit 1 || exit 0'

check "dockerd is not listening on any TCP port" \
  bash -c 'sudo ss -ltnp 2>/dev/null | grep -q "dockerd" && exit 1 || exit 0'

check "port 2375 is not listening" \
  bash -c 'sudo ss -ltn 2>/dev/null | grep -q ":2375 " && exit 1 || exit 0'

# 4. docker still works
check "the docker service is active" \
  bash -c 'sudo systemctl is-active --quiet docker'

check "docker is usable over the unix socket" \
  bash -c 'sudo docker info >/dev/null 2>&1'

echo ""
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "All checks passed!" || echo "Some checks failed."
exit $FAIL
