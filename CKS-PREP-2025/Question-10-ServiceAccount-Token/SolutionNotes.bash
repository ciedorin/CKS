# Question 10 - ServiceAccount token - Solution

# Part 1 - stop auto mounting the credentials on the ServiceAccount
kubectl edit serviceaccount stats-monitor-sa -n monitoring
# set:
#   automountServiceAccountToken: false

# Or in one shot:
kubectl patch serviceaccount stats-monitor-sa -n monitoring \
  -p '{"automountServiceAccountToken": false}'

kubectl get sa stats-monitor-sa -n monitoring -o yaml | grep automount

# Part 2 - mount the token explicitly where the app expects it
kubectl edit deployment stats-monitor -n monitoring

# Add to spec.template.spec:
#
#      volumes:
#      - name: sa-token
#        projected:
#          sources:
#          - serviceAccountToken:
#              path: token
#              expirationSeconds: 3600
#              audience: api
#
# and to the container:
#
#        volumeMounts:
#        - name: sa-token
#          mountPath: /var/run/secrets/stats-monitor
#          readOnly: true

# Watch the rollout
kubectl rollout status deployment stats-monitor -n monitoring

# Verify
kubectl exec -n monitoring deploy/stats-monitor -- ls -l /var/run/secrets/stats-monitor
kubectl exec -n monitoring deploy/stats-monitor -- head -c 40 /var/run/secrets/stats-monitor/token

# The default location must be gone now:
kubectl exec -n monitoring deploy/stats-monitor -- ls /var/run/secrets/kubernetes.io/serviceaccount
# expected: No such file or directory
