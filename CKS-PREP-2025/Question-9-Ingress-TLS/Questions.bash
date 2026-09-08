# Question 9 - Ingress with TLS termination

# Context:
# The namespace prod contains a Deployment "web" exposed by a Service "web" on
# port 80. A TLS Secret named "web-cert" already exists in the same namespace.

# Task:
# Create an Ingress named "web" in the namespace prod that:
#
# 1. routes the host web.k8s.local, all paths, to the Service "web" on port 80
# 2. terminates TLS for that host using the Secret "web-cert"
# 3. redirects plain HTTP requests to HTTPS
#
# Use the "nginx" IngressClass.

# Verify:
#   kubectl get ingress -n prod
#   # add the ingress controller address to /etc/hosts as web.k8s.local, then:
#   curl -kIL http://web.k8s.local     # must answer 308 Permanent Redirect to https
#   curl -k   https://web.k8s.local    # must serve the nginx welcome page

# Documentation Reference
# Tip: Navigate the documentation manually to build familiarity with its structure
# Concepts -> Services, Load Balancing, and Networking -> Ingress -> TLS
# https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
# ingress-nginx annotations (server side HTTPS enforcement)
# https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#server-side-https-enforcement-through-redirect
