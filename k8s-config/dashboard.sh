########################################################################################################

# dashboard.sh

########################################################################################################

MYDIR=$WORK_DIR/dashboard
KNS=kubernetes-dashboard
mkdir -p $MYDIR

wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc2/aio/deploy/recommended.yaml -O $MYDIR/recommended.yaml

cat > $MYDIR/ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: nginx-intranet
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: cert-issuer-prod
    nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"
    nginx.ingress.kubernetes.io/auth-url: "https://login.laurelnaiad.com/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://login.laurelnaiad.com/oauth2/start?rd=https%3A%2F%2F\$host\$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "x-auth-request-user, x-auth-request-email, authorization"
spec:
  rules:
  - host: $DASHBOARD_HOST.intranet.$PRI_DOMAIN
    http:
      paths:
      - backend:
          serviceName: kubernetes-dashboard
          servicePort: 80
  tls:
  - hosts:
    - $DASHBOARD_HOST.intranet.$PRI_DOMAIN
    secretName: $DASHBOARD_HOST.intranet.$PRI_DOMAIN-tls
EOF

cat > $MYDIR/kustomization.yaml <<EOF
resources:
- recommended.yaml
- ingress.yaml
patchesJson6902:
- target:
    group: apps
    version: v1
    namespace: kubernetes-dashboard
    name: kubernetes-dashboard
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/args
      value:
      - --namespace=kubernetes-dashboard
      - --insecure-bind-address=0.0.0.0
      - --auto-generate-certificates=false
      - --enable-insecure-login=true
    - op: replace
      path: /spec/template/spec/containers/0/livenessProbe/httpGet/port
      value: 9090
    - op: replace
      path: /spec/template/spec/containers/0/livenessProbe/httpGet/scheme
      value: HTTP
- target:
    version: v1
    namespace: kubernetes-dashboard
    name: kubernetes-dashboard
    kind: Service
  patch: |-
    - op: replace
      path: /spec/ports/0
      value:
        port: 80
        targetPort: 9090
EOF

kustomize build $MYDIR > $MYDIR/package.yaml

kubectl apply -f $MYDIR/package.yaml
