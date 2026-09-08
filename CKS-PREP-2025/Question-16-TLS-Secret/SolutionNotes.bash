# Question 16 - TLS Secret - Solution

# Step 0: look at what is there
ls -l /opt/course/16/
kubectl get pods -n clever-cactus            # ContainerCreating: secret not found
kubectl describe pod -n clever-cactus | tail -5

# Step 1: create the TLS secret from the two files
kubectl create secret tls clever-cactus -n clever-cactus \
  --cert=/opt/course/16/clever-cactus.crt \
  --key=/opt/course/16/clever-cactus.key

# The equivalent YAML (the data has to be base64 of the file contents):
#
#   apiVersion: v1
#   kind: Secret
#   metadata:
#     name: clever-cactus
#     namespace: clever-cactus
#   type: kubernetes.io/tls
#   data:
#     tls.crt: <base64 of clever-cactus.crt>
#     tls.key: <base64 of clever-cactus.key>

# Step 2: verify
kubectl get secret clever-cactus -n clever-cactus
kubectl get secret clever-cactus -n clever-cactus -o jsonpath='{.type}{"\n"}'   # kubernetes.io/tls

kubectl get pods -n clever-cactus            # Running

# Confirm the certificate really landed in the pod:
kubectl exec -n clever-cactus deploy/clever-cactus -- ls -l /etc/nginx/tls
kubectl get secret clever-cactus -n clever-cactus -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -subject
