# Question 14 - Docker daemon hardening - Solution

# Part 1 - take the user out of the docker group
id -nG developer                     # developer docker
sudo gpasswd -d developer docker     # or: sudo deluser developer docker
id -nG developer                     # docker must be gone

# Part 2 + 3 - fix the daemon configuration
sudo vim /etc/docker/daemon.json

# Remove the tcp:// entry and the "group" override. The result:
cat <<'EOF'
{
  "hosts": ["unix:///var/run/docker.sock"]
}
EOF

# "group": "developer" is what makes the socket group owned by developer.
# Removing it makes dockerd fall back to the default group "docker"; to get the
# group "root" as the task requires, set it explicitly:
cat <<'EOF'
{
  "hosts": ["unix:///var/run/docker.sock"],
  "group": "root"
}
EOF

# Restart and verify
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl status docker

stat -c '%U:%G' /var/run/docker.sock     # root:root
sudo ss -ltnp | grep dockerd             # no output = no TCP listener
sudo docker info                         # docker still works over the socket

# Note: if dockerd fails to start with
#   "unable to configure the Docker daemon with file /etc/docker/daemon.json:
#    the following directives are specified both as a flag and in the file: hosts"
# then the systemd unit also passes -H. Check:
sudo systemctl cat docker | grep ExecStart
# and either remove "hosts" from daemon.json or override ExecStart in
# /etc/systemd/system/docker.service.d/
