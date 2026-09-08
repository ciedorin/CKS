# Question 6 - Container immutability - Solution

# Step 1: edit the deployment
kubectl edit deployment lamp-deployment -n lamp

# Add a securityContext to EVERY container in spec.template.spec.containers:
#
#      containers:
#      - name: apache
#        image: busybox:1.36
#        securityContext:
#          runAsUser: 20004
#          readOnlyRootFilesystem: true
#          allowPrivilegeEscalation: false
#      - name: mysql
#        image: busybox:1.36
#        securityContext:
#          runAsUser: 20004
#          readOnlyRootFilesystem: true
#          allowPrivilegeEscalation: false

# runAsUser may also be set once at pod level, but readOnlyRootFilesystem and
# allowPrivilegeEscalation exist ONLY at container level, so they have to be
# repeated for each container:
#
#    spec:
#      template:
#        spec:
#          securityContext:
#            runAsUser: 20004        # pod level - inherited by both containers

# Step 2: watch the rollout
kubectl rollout status deployment lamp-deployment -n lamp
kubectl get pods -n lamp

# Step 3: verify
kubectl get deployment lamp-deployment -n lamp \
  -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{": "}{.securityContext}{"\n"}{end}'

# Prove it from inside the container:
POD=$(kubectl get pods -n lamp -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n lamp "$POD" -c apache -- id            # uid=20004
kubectl exec -n lamp "$POD" -c apache -- touch /tmp-x  # must fail: read-only file system
