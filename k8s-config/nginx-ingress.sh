########################################################################

# nginx-ingress.sh

# https://kubernetes.github.io/ingress-nginx/deploy/
# https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/#multiple-ingress-nginx-controllers

# to run an intranet site:

# kind: Ingress
# metadata:
#   name: hello-world
#   annotations:
#     kubernetes.io/ingress.class: nginx-intranet   # <== class for intranet
#     nginx.ingress.kubernetes.io/rewrite-target: /
# spec:
#   rules:
#   - host: hello.intranet.$PRI_DOMAIN

# to run an internet site:

# kind: Ingress
# metadata:
#   name: hello-world
#   annotations:
#     kubernetes.io/ingress.class: nginx          # <== class for public/internet
#     nginx.ingress.kubernetes.io/rewrite-target: /
# spec:
#   rules:
#   - host: hello.$PRI_DOMAIN

# Kubernetes doesn't know from "private" in this context.
# It is up to the lan's firewall config to make this distinction real, by
# forwarding inbound packets to the public nginx endpoint, and not to the
# private one. :)

########################################################################

MYDIR=$WORK_DIR/nginx-ingress
mkdir -p $MYDIR

########################################################################
# certs
########################################################################
kubectl create namespace ingress-nginx

cat <<EOF > $MYDIR/pri-domain-cert.yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: $PRI_DOMAIN
  namespace: ingress-nginx
spec:
  secretName: $PRI_DOMAIN-tls
  dnsNames:
  - "$PRI_DOMAIN"
  - "*.$PRI_DOMAIN"
  issuerRef:
    name: cert-issuer-prod
    kind: ClusterIssuer
    group: cert-manager.io
EOF
cat <<EOF > $MYDIR/intranet-cert.yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: intranet.$PRI_DOMAIN
  namespace: ingress-nginx
spec:
  secretName: intranet.$PRI_DOMAIN-tls
  dnsNames:
  - "intranet.$PRI_DOMAIN"
  - "*.intranet.$PRI_DOMAIN"
  issuerRef:
    name: cert-issuer-prod
    kind: ClusterIssuer
    group: cert-manager.io
EOF

kubectl apply -f $MYDIR/pri-domain-cert.yaml
kubectl apply -f $MYDIR/intranet-cert.yaml

sleep 5
until [ $( \
  kubectl get certs -n ingress-nginx -o yaml | yq '
    (.items[0].status.conditions[0].reason | test("Ready"))
      and
    (.items[1].status.conditions[0].reason | test("Ready"))
  ') == "true" ]
do
  echo "`date +%r` --  waiting for certificate to be ready (typically several minutes):"
  echo "  status:"
  kubectl get certs -n ingress-nginx -o yaml | yq -r '
    .items[] | "    " + .metadata.name + ": " + .status.conditions[0].reason
  '
  sleep 5
done
echo "*** success! ***"
kubectl get certs -n ingress-nginx -o yaml | yq -r '
  .items[] | "    " + .metadata.name + ": " + .status.conditions[0].reason
'


########################################################################
# NGINX-INGRESS
########################################################################

wget -O $MYDIR/mandatory.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.2/deploy/static/mandatory.yaml
wget -O $MYDIR/ingress-config.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.2/deploy/static/provider/cloud-generic.yaml

CFGMP=$(cat $MYDIR/mandatory.yaml | yq -y '. | select(.kind | test("ConfigMap")) | select(.metadata.name | test("nginx-configuration"))')
echo "$CFGMP" | yq -y '.metadata.name = "nginx-configuration-intranet"' > $MYDIR/second-configmap.yaml

cat $MYDIR/mandatory.yaml | yq -y --arg SECRET ingress-nginx/intranet.$PRI_DOMAIN-tls '. |
    select(.kind | test("Deployment"))
  | .metadata.name = "nginx-ingress-controller-intranet"
  | .spec.template.spec.containers[0].name = "nginx-ingress-controller-intranet"
  | .spec.template.spec.containers[0].args[1] = "--configmap=$(POD_NAMESPACE)/nginx-configuration-intranet"
  | .spec.template.spec.containers[0].args[4] = "--publish-service=$(POD_NAMESPACE)/ingress-nginx-intranet"
  | .spec.template.spec.containers[0].args[6] = "--election-id=ingress-controller-leader-intranet"
  | .spec.template.spec.containers[0].args[7] = "--ingress-class=nginx-intranet"
  | .spec.template.spec.containers[0].args[8] = "--default-ssl-certificate=" + $SECRET
' | tee $MYDIR/second-deployment.yaml

cat $MYDIR/mandatory.yaml | yq -y --arg SECRET ingress-nginx/$PRI_DOMAIN-tls '. |
  if .kind | test("Deployment") then
    .spec.template.spec.containers[0].args[6] = "--default-ssl-certificate=" + $SECRET
  else
    .
  end
' | tee $MYDIR/mandatory.yaml

cat $MYDIR/ingress-config.yaml | yq -y '. | select(.kind | test("Service")) | .metadata.name = "ingress-nginx-intranet"' > $MYDIR/second-service.yaml

wget -O $MYDIR/default-backend.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/docs/examples/customization/custom-errors/custom-default-backend.yaml

cat <<EOF > $MYDIR/default-ingress-public.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1beta1
metadata:
  name: default-backend
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    scope: public
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: "*.$PRI_DOMAIN"
    http:
      paths:
      - backend:
          serviceName: nginx-errors
          servicePort: 80
  tls:
  - hosts:
    - "*.$PRI_DOMAIN"
    secretName: $PRI_DOMAIN-tls
EOF

cat > $MYDIR/ingress-errors.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-errors
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: nginx-errors
    app.kubernetes.io/part-of: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: nginx-errors
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nginx-errors
        app.kubernetes.io/part-of: ingress-nginx
    spec:
      containers:
      - name: nginx-error-server
        image: quay.io/kubernetes-ingress-controller/custom-error-pages-amd64:0.3
        ports:
        - containerPort: 8080
        env:
        - name: DEBUG
          value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-errors
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: nginx-errors
    app.kubernetes.io/part-of: ingress-nginx
spec:
  selector:
    app.kubernetes.io/name: nginx-errors
    app.kubernetes.io/part-of: ingress-nginx
  ports:
  - port: 80
    targetPort: 8080
    name: http
EOF

cat $MYDIR/default-ingress-public.yaml | yq -y --arg DOMAIN intranet.$PRI_DOMAIN '.
  | .metadata.name = "default-backend-intranet"
  | .metadata.labels.scope = "intranet"
  | .metadata.annotations["kubernetes.io/ingress.class"] = "nginx-intranet"
  | .spec.rules[0].host = "*." + $DOMAIN
  | .spec.tls[0].hosts[0] = "*." + $DOMAIN
  | .spec.tls[0].secretName = $DOMAIN
' | tee $MYDIR/default-ingress-intranet.yaml

cat <<EOF > $MYDIR/kustomization.yaml
resources:
- mandatory.yaml
- ingress-config.yaml
- second-configmap.yaml
- second-deployment.yaml
- second-service.yaml
- default-backend.yaml
- default-ingress-public.yaml
- default-ingress-intranet.yaml
- ingress-errors.yaml
patchesJson6902:
- target:
    name: nginx-ingress-role
    kind: Role
    group: rbac.authorization.k8s.io
    version: v1beta1
    namespace: ingress-nginx
  patch: |-
    - op: replace
      path: /rules/1/resourceNames
      value: [ "ingress-controller-leader-nginx", "ingress-controller-leader-intranet-nginx-intranet" ]
- target:
    name: nginx-ingress-controller
    kind: Deployment
    group: apps
    version: v1
    namespace: ingress-nginx
  patch: |-
    - op: add
      path: /metadata/labels/scope
      value: public
    - op: add
      path: /spec/selector/matchLabels/scope
      value: public
    - op: add
      path: /spec/template/metadata/labels/scope
      value: public
- target:
    name: nginx-ingress-controller-intranet
    kind: Deployment
    group: apps
    version: v1
    namespace: ingress-nginx
  patch: |-
    - op: add
      path: /metadata/labels/scope
      value: intranet
    - op: add
      path: /spec/selector/matchLabels/scope
      value: intranet
    - op: add
      path: /spec/template/metadata/labels/scope
      value: intranet
- target:
    name: ingress-nginx
    kind: Service
    version: v1
    namespace: ingress-nginx
  patch: |-
    - op: add
      path: /metadata/annotations
      value: { "metallb.universe.tf/address-pool": "load-balancer" }
    - op: add
      path: /metadata/labels/scope
      value: public
    - op: add
      path: /spec/selector/scope
      value: public
- target:
    name: ingress-nginx-intranet
    kind: Service
    version: v1
    namespace: ingress-nginx
  patch: |-
    - op: add
      path: /metadata/annotations
      value: { "metallb.universe.tf/address-pool": "load-balancer-intranet" }
    - op: add
      path: /metadata/labels/scope
      value: intranet
    - op: add
      path: /spec/selector/scope
      value: intranet
EOF
kustomize build $MYDIR > $MYDIR/package.yaml
kubectl apply -f $MYDIR/package.yaml
