########################################################################

# cert-manager.sh

# Getting wildcard SSL certificate in Kubernetes with cert-manager
# https://medium.com/@Amet13/wildcard-k8s-4998173b16c8

# this assumes one is using AWS Route53...see also env-vars.sh and secure-vars.sh

########################################################################
MYDIR=$WORK_DIR/cert-manager
mkdir -p $MYDIR
MY_SECRET=aws-iam-cert-manager
kubectl create namespace cert-manager

# initial filter removes helm detritus documents
curl -L https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager.yaml \
  | yq -y '.
    | select(.kind | test(".+"))
' > $MYDIR/cert-manager.yaml

# setting dns01-recursive-nameservers is critical, because cert-manager would
# otherwise wind up consulting resolv.conf, then 127.0.0.1, then 10.0.2.1,
# which considers itself authoritative over intranet.$PRI_DOMAIN. cert-manager
# needs the _real_ authoritative server, though, and using public
# dns01-recursive-nameservers accomplishes that.
cat $MYDIR/cert-manager.yaml | yq -y '.
  | select((.kind | test("Deployment")) and (.metadata.name | test("cert-manager$")))
  | .spec.template.spec.containers[0].args[7] = "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53"
  | .spec.template.spec.containers[0].args[8] = "--dns01-recursive-nameservers-only=true"
' > $MYDIR/cert-manager-controller.yaml
cat $MYDIR/cert-manager.yaml | yq -y '.
  | select((.kind | test("Deployment") | not) or (.metadata.name | test("cert-manager$") | not))
' > $MYDIR/cert-manager-everthing-else.yaml

kubectl apply -f $MYDIR/cert-manager-everthing-else.yaml
kubectl apply -f $MYDIR/cert-manager-controller.yaml

until [ $(kubectl get pods --namespace cert-manager \
    | awk '{if(/-webhook-/) {print $2}}' \
    | awk -F/ '{print $1}') -gt 0 ]
do
  echo "`date +%r` -- waiting for cert-manager webhook to be ready (typically a few minutes)"
  sleep 5
done

# create a sealed secret of the aws credentials
 echo -n ${AWS_SECRET_ACCESS_KEY} \
  | kubectl create secret generic \
      -n cert-manager $MY_SECRET \
      --dry-run \
      --from-file=password.txt=/dev/stdin \
      -o json \
  | kubeseal --cert $SSCERT \
  >$MYDIR/$MY_SECRET.sealed.json
kubectl apply -f $MYDIR/$MY_SECRET.sealed.json
mkdir -p $MYDIR/base
mkdir -p $MYDIR/overlays/staging
mkdir -p $MYDIR/overlays/prod
cat <<EOF | tee $MYDIR/base/cert-issuer.yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: cert-issuer
spec:
  acme:
    # server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $CERT_EMAIL
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - selector:
        dnsZones:
        - $PRI_DOMAIN
      dns01:
        route53:
          region: $AWS_REGION
          accessKeyID: $AWS_ACCESS_KEY_ID
          role: $AWS_ROLE_ID
          secretAccessKeySecretRef:
            name: $MY_SECRET
            key: password.txt
EOF
cat <<EOF | tee $MYDIR/base/kustomization.yaml
resources:
- cert-issuer.yaml
EOF
cat <<EOF | tee $MYDIR/overlays/staging/kustomization.yaml
bases:
- ../../base
patchesJson6902:
- target:
    group: cert-manager.io
    kind: ClusterIssuer
    version: v1alpha2
    name: cert-issuer
  patch: |-
    - op: replace
      path: /metadata/name
      value: cert-issuer-staging
    - op: replace
      path: /spec/acme/server
      value: https://acme-staging-v02.api.letsencrypt.org/directory
    - op: replace
      path: /spec/acme/privateKeySecretRef/name
      value: letsencrypt-staging
EOF
cat <<EOF | tee $MYDIR/overlays/prod/kustomization.yaml
bases:
- ../../base
patchesJson6902:
- target:
    group: cert-manager.io
    kind: ClusterIssuer
    version: v1alpha2
    name: cert-issuer
  patch: |-
    - op: replace
      path: /metadata/name
      value: cert-issuer-prod
    - op: replace
      path: /spec/acme/server
      value: https://acme-v02.api.letsencrypt.org/directory
    - op: replace
      path: /spec/acme/privateKeySecretRef/name
      value: letsencrypt-prod
EOF
kustomize build $MYDIR/overlays/staging | kubectl apply -f -
kustomize build $MYDIR/overlays/prod | kubectl apply -f -

kubectl create namespace test-certs
PRI_DOMAIN_DASH=$(echo $PRI_DOMAIN | sed 's/\./-/g')
cat <<EOF > $MYDIR/pri-domain-cert.yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: $PRI_DOMAIN_DASH
  namespace: test-certs
spec:
  secretName: $PRI_DOMAIN_DASH-tls
  dnsNames:
  - "$PRI_DOMAIN"
  - "*.$PRI_DOMAIN"
  issuerRef:
    name: cert-issuer-staging
    kind: ClusterIssuer
    group: cert-manager.io
EOF

cat <<EOF > $MYDIR/intranet-cert.yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: intranet-$PRI_DOMAIN_DASH
  namespace: test-certs
spec:
  secretName: intranet-$PRI_DOMAIN_DASH-tls
  dnsNames:
  - "intranet.$PRI_DOMAIN"
  - "*.intranet.$PRI_DOMAIN"
  issuerRef:
    name: cert-issuer-staging
    kind: ClusterIssuer
    group: cert-manager.io
EOF

kubectl apply -f $MYDIR/pri-domain-cert.yaml
kubectl apply -f $MYDIR/intranet-cert.yaml
sleep 5
until [ $( \
  kubectl get certs -n test-certs -o yaml | yq '
    (.items[0].status.conditions[0].reason | test("Ready"))
      and
    (.items[1].status.conditions[0].reason | test("Ready"))
  ') == "true" ]
do
  echo "`date +%r` --  waiting for test certificates to be ready (typically several minutes):"
  echo "  status:"
  kubectl get certs -n test-certs -o yaml | yq -r '
    .items[] | "    " + .metadata.name + ": " + .status.conditions[0].reason
  '
  sleep 5
done
echo "*** success! ***"
kubectl get certs -n test-certs -o yaml | yq -r '
  .items[] | "    " + .metadata.name + ": " + .status.conditions[0].reason
'

# shared certs are problematic, because the whole point is to share them, but
# the only way to share them is to copy them between namepaces. But when a cert
# is renewed, we'd need to copy it to the various namespaces, and there's no
# automatic way to do that. Net/net it's, easier to just avoid shared wildcards
# and let each ingress manage a certificate. Wildcards will be used by the
# default backendsd for the two ingress controllers.
# so...
echo "test certs having been successfully generated, now deleting them"
kubectl delete namespace test-certs
