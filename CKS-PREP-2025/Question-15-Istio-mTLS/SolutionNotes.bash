# Question 15 - Istio mutual TLS - Solution

# Part 1 - sidecar injection for the whole namespace
kubectl get pods -n mtls                       # 1/1 -> no sidecar
kubectl get namespace mtls --show-labels

kubectl label namespace mtls istio-injection=enabled --overwrite

# The label only affects NEW pods, so restart the existing workloads:
kubectl rollout restart deployment -n mtls --all
kubectl rollout status deployment frontend -n mtls
kubectl rollout status deployment backend -n mtls

kubectl get pods -n mtls                       # now 2/2
kubectl get pod -n mtls -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.containers[*].name}{"\n"}{end}'

# Part 2 - STRICT mutual TLS for the whole namespace
cat <<'EOF' > peer-authentication.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mtls
spec:
  mtls:
    mode: STRICT
EOF
kubectl apply -f peer-authentication.yaml

# Note: NO selector means "every workload in this namespace".
# A selector would narrow it down to one workload, which is not what is asked.

# Verify
kubectl get peerauthentication -n mtls
kubectl get peerauthentication default -n mtls -o jsonpath='{.spec.mtls.mode}{"\n"}'

# Plaintext from outside the mesh must now fail:
kubectl run plain --rm -it --image=curlimages/curl:8.9.1 --restart=Never -n default -- \
  curl -s --max-time 5 http://frontend.mtls.svc.cluster.local
# expected: empty reply / connection reset

# While mesh traffic still works:
kubectl exec -n mtls deploy/frontend -c nginx -- curl -s -o /dev/null -w "%{http_code}\n" http://backend.mtls.svc.cluster.local
