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
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml

until [ $(kubectl get pods --namespace cert-manager \
    | awk '{if(/-webhook-/) {print $2}}' \
    | awk -F/ '{print $1}') -gt 0 ]
do
  echo "waiting for cert-manager webhook to be ready"
  sleep 2
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
