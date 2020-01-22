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

# it is up to the lan's firewall config to make this distinction real, by forwarding
# inbound packets to the public nginx endpoint, and not to the private one. :)

########################################################################

MYDIR=$WORK_DIR/nginx-ingress
mkdir -p $MYDIR
wget -O $MYDIR/mandatory.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.2/deploy/static/mandatory.yaml
wget -O $MYDIR/ingress-config.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.2/deploy/static/provider/cloud-generic.yaml

CFGMP=$(cat $MYDIR/mandatory.yaml | yq -y '. | select(.kind | test("ConfigMap")) | select(.metadata.name | test("nginx-configuration"))')
echo "$CFGMP" | yq -y '.metadata.name = "nginx-configuration-intranet"' > $MYDIR/second-configmap.yaml

cat $MYDIR/mandatory.yaml | yq -y '. | select(.kind | test("Deployment"))
  | .metadata.name = "nginx-ingress-controller-intranet"
  | .spec.template.spec.containers[0].name = "nginx-ingress-controller-intranet"
  | .spec.template.spec.containers[0].args[1] = "--configmap=$(POD_NAMESPACE)/nginx-configuration-intranet"
  | .spec.template.spec.containers[0].args[4] = "--publish-service=$(POD_NAMESPACE)/ingress-nginx-intranet"
  | .spec.template.spec.containers[0].args[6] = "--election-id=ingress-controller-leader-intranet"
  | .spec.template.spec.containers[0].args[7] = "--ingress-class=nginx-intranet"
' > $MYDIR/second-deployment.yaml

cat $MYDIR/ingress-config.yaml | yq -y '. | select(.kind | test("Service")) | .metadata.name = "ingress-nginx-intranet"' > $MYDIR/second-service.yaml

cat <<EOF > $MYDIR/kustomization.yaml
resources:
- mandatory.yaml
- ingress-config.yaml
- second-configmap.yaml
- second-deployment.yaml
- second-service.yaml
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
