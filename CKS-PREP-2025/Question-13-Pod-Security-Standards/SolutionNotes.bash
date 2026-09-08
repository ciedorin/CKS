# Question 13 - Pod Security Standards - Solution

# Step 1: see why the pods are rejected
kubectl get deployment,rs,pods -n confidential
kubectl get events -n confidential --sort-by=.lastTimestamp | tail -10
kubectl describe rs -n confidential | tail -20
# The message lists exactly what "restricted" requires:
#   allowPrivilegeEscalation != false
#   unrestricted capabilities (must drop ALL)
#   runAsNonRoot != true
#   seccompProfile type not set to RuntimeDefault or Localhost

# Step 2: make the workload compliant
kubectl edit deployment confidential-app -n confidential

# spec.template.spec becomes:
#
#    spec:
#      securityContext:
#        runAsNonRoot: true
#        runAsUser: 1000
#        seccompProfile:
#          type: RuntimeDefault
#      containers:
#      - name: app
#        image: busybox:1.36
#        command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
#        securityContext:
#          allowPrivilegeEscalation: false
#          capabilities:
#            drop: ["ALL"]

# The four things "restricted" demands from every container:
#   1. allowPrivilegeEscalation: false
#   2. capabilities.drop: ["ALL"]
#   3. runAsNonRoot: true      (pod or container level)
#   4. seccompProfile.type: RuntimeDefault   (pod or container level)
# runAsUser must be non zero, otherwise runAsNonRoot: true fails at startup.

# Step 3: verify
kubectl rollout status deployment confidential-app -n confidential
kubectl get pods -n confidential
kubectl get events -n confidential --sort-by=.lastTimestamp | tail -3
