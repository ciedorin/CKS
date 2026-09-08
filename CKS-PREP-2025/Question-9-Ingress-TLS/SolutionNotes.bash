# Question 9 - Ingress with TLS termination - Solution

kubectl get secret web-cert -n prod        # already exists, type kubernetes.io/tls
kubectl get svc web -n prod                # ClusterIP on port 80

cat <<'EOF' > ingress-web.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: prod
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - web.k8s.local
    secretName: web-cert
  rules:
  - host: web.k8s.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
EOF
kubectl apply -f ingress-web.yaml

# Notes:
#  - ssl-redirect is on by default in ingress-nginx as soon as a TLS block exists,
#    but the task asks for the redirect explicitly, so set the annotation.
#  - force-ssl-redirect also redirects when TLS is terminated further upstream.

# Verify
kubectl get ingress web -n prod
kubectl describe ingress web -n prod

# Resolve the hostname to the controller and test:
CONTROLLER_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.clusterIP}')
echo "$CONTROLLER_IP web.k8s.local" | sudo tee -a /etc/hosts

curl -kIL http://web.k8s.local        # 308 -> https
curl -k https://web.k8s.local         # nginx welcome page
