########################################################################

# oauth2_proxy.sh

# https://thenewstack.io/single-sign-on-for-kubernetes-dashboard-experience/
# https://github.com/pusher/oauth2_proxy/issues/216
# https://pusher.github.io/oauth2_proxy/configuration
# https://pusher.github.io/oauth2_proxy/auth-configuration#openid-connect-provider
# https://github.com/kubernetes/ingress-nginx/blob/19e9e9d7ed9d016d64ed726bb48513dfedd423a5/docs/examples/auth/oauth-external-auth/oauth2-proxy.yaml
# https://www.digitalocean.com/community/tutorials/how-to-protect-private-kubernetes-services-behind-a-github-login-with-oauth2_proxy

# current latest image: quay.io/pusher/oauth2_proxy:v5.0.0-amd64

########################################################################
source "${0%/*}/../lib/all.sh"
MYDIR=$WORK_DIR/oauth2_proxy
mkdir -p $MYDIR
KNS=oauth2-proxy

COOKIE_SEC=$(generate_reasonable_password)

cat > $MYDIR/resources.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: $KNS
  labels:
    k8s-app: oauth2-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: oauth2-proxy
  template:
    metadata:
      labels:
        k8s-app: oauth2-proxy
    spec:
      containers:
      - image: quay.io/pusher/oauth2_proxy:v5.0.0-amd64
        # image: docker-registry.intranet.laurelnaiad.com/oauth2_proxy:latest
        imagePullPolicy: Always
        name: oauth2-proxy
        args:
        - --http-address=0.0.0.0:4180
        - --provider=oidc
        - --oidc-issuer-url=$DEX_ISSUER_URL
        - --client-id=kubernetes
        - --client-secret=kubernetes-client-secret
        - --redirect-url=$LOGIN_APP_URL/callback
        - --email-domain=*
        - '--scope=openid profile email groups offline_access'
        # - --scope="openid profile email groups offline_access"
        - --cookie-domain=.$PRI_DOMAIN
        - --cookie-refresh=24h
        - --cookie-secret=$COOKIE_SEC
        - --set-authorization-header=true
        - --silence-ping-logging=true
        - --whitelist-domain=.intranet.$PRI_DOMAIN
        - --whitelist-domain=$PRI_DOMAIN
        - --whitelist-domain=.$PRI_DOMAIN
        - --whitelist-domain=intranet.$PRI_DOMAIN
        ports:
        - containerPort: 4180
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /ping
            port: 4180
            scheme: HTTP
          initialDelaySeconds: 0
          timeoutSeconds: 1
        readinessProbe:
          httpGet:
            path: /ping
            port: 4180
            scheme: HTTP
          initialDelaySeconds: 0
          timeoutSeconds: 1
          successThreshold: 1
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: $KNS
  labels:
    k8s-app: oauth2-proxy
spec:
  ports:
  - name: http
    port: 4180
    protocol: TCP
    targetPort: 4180
  selector:
    k8s-app: oauth2-proxy
---
kind: Ingress
apiVersion: networking.k8s.io/v1beta1
metadata:
  name: oauth2-proxy
  namespace: $KNS
  labels:
    k8s-app: oauth2-proxy
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: cert-issuer-prod
spec:
  rules:
  - host: $LOGIN_APP_FQDN
    http:
      paths:
      - backend:
          serviceName: oauth2-proxy
          servicePort: 4180
  tls:
  - hosts:
    - $LOGIN_APP_FQDN
    secretName: $LOGIN_APP_FQDN-tls
EOF

kubectl create namespace $KNS
kubectl apply -f $MYDIR/resources.yaml

# ingresses to be authenticated by the proxy should be configured with these annotations:
  # nginx.ingress.kubernetes.io/auth-url: "$LOGIN_APP_URL/auth"
  # nginx.ingress.kubernetes.io/auth-signin: "$LOGIN_APP_URL/start?rd=https%3A%2F%2F\$host\$escaped_request_uri"
  # nginx.ingress.kubernetes.io/auth-response-headers: "x-auth-request-user, x-auth-request-email, authorization"
