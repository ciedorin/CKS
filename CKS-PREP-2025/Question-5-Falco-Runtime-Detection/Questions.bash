# Question 5 - Falco: misbehaving pod

# Context:
# Falco is running on this node. The ollama application in the namespace "ollama"
# consists of three Deployments, each running a single pod.
#
# One of those pods is directly reading the sensitive device file /dev/mem
# (physical memory), which is a strong indicator of a compromised workload.

# Task:
# 1. Use Falco to identify the misbehaving pod that reads /dev/mem
# 2. Identify the Deployment that manages that pod
# 3. Scale that Deployment down to zero replicas
#
# Leave the other two Deployments running.

# Hints:
# Falco does not always run as a unit called "falco" - depending on the driver it
# is installed as falco-modern-bpf, falco-bpf or falco-kmod. Find it first:
#
#   systemctl list-units --all 'falco*'
#   FALCO_UNIT=$(systemctl list-units --state=running 'falco*' --no-legend | awk '{print $1}')
#
# Then read the alerts:
#
#   sudo journalctl -fu falco-modern-bpf                    # live alerts
#   sudo journalctl -u falco-modern-bpf | grep -i "/dev/mem" # historical alerts
#   sudo grep -i falco /var/log/syslog | grep "/dev/mem"
#
# Falco alerts may take up to ~30 seconds to appear after the lab setup.

# Documentation Reference
# Falco - Rules and outputs
# https://falco.org/docs/reference/rules/
# Falco - Running Falco (systemd services per driver)
# https://falco.org/docs/setup/packages/
# Concepts -> Workloads -> Deployments -> Scaling a Deployment
# https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#scaling-a-deployment
