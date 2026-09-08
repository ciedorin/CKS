# Question 8 - NetworkPolicies - Solution

# Part 1 - deny all ingress in namespace prod
cat <<'EOF' > deny-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-policy
  namespace: prod
spec:
  podSelector: {}          # every pod in the namespace
  policyTypes:
  - Ingress                # no ingress rules at all => deny everything
EOF
kubectl apply -f deny-policy.yaml

# Part 2 - in namespace data, allow ingress only from namespace prod
kubectl get namespace prod --show-labels     # env=prod (and kubernetes.io/metadata.name=prod)

cat <<'EOF' > allow-from-prod.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-prod
  namespace: data
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          env: prod
EOF
kubectl apply -f allow-from-prod.yaml

# Careful:
#  - a "from" list with several entries is an OR, each extra entry widens access
#  - namespaceSelector: {} would match EVERY namespace - that is not what is asked

# Verify
kubectl get networkpolicy -A

kubectl exec -n prod deploy/client -- curl -s --max-time 5 -o /dev/null -w "prod->data:  %{http_code}\n" http://db.data.svc.cluster.local
kubectl exec -n other deploy/intruder -- curl -s --max-time 5 -o /dev/null -w "other->data: %{http_code}\n" http://db.data.svc.cluster.local
kubectl exec -n other deploy/intruder -- curl -s --max-time 5 -o /dev/null -w "other->prod: %{http_code}\n" http://web.prod.svc.cluster.local
