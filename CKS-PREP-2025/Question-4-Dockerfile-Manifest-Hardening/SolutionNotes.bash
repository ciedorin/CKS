# Question 4 - Dockerfile and manifest hardening - Solution

# Part 1 - the Dockerfile
sudo vim /home/candidate/app/Dockerfile

# The offending instruction is the explicit root user:
#
#   USER root      <-- remove/replace
#   USER nobody    <-- the fix (one line changed, nothing else touched)
#
# Note: only the LAST USER instruction takes effect, so the fix must be on that line.

sed -n '1,20p' /home/candidate/app/Dockerfile     # review the result

# Part 2 - the Deployment manifest
sudo vim /home/candidate/app/deployment.yaml

# The offending field is in the container securityContext:
#
#   privileged: true     <-- the single security issue
#   privileged: false    <-- the fix
#
# Everything else in that securityContext is already correct and must stay:
#   allowPrivilegeEscalation: false
#   readOnlyRootFilesystem: true
#   runAsUser: 10001

grep -A6 securityContext /home/candidate/app/deployment.yaml
