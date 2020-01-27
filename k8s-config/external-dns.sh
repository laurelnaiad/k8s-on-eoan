########################################################################

# external-dns.sh

########################################################################
source "${0%/*}/../lib/all.sh"
MYDIR=$WORK_DIR/external-dns
KNS=external-dns
mkdir -p $MYDIR

#############################################################################
# external-dns
#############################################################################
# https://github.com/kubernetes-sigs/external-dns/blob/master/docs/faq.md#running-an-internal-and-external-dns-service

cat <<EOF > $MYDIR/external-dns.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: $KNS
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: $KNS
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: $KNS
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.opensource.zalan.do/teapot/external-dns:v0.5.9
        args:
        - --source=ingress
        - --source=service
        - --provider=pdns
        - --pdns-server=http://powerdns.powerdns:8081
        - --pdns-api-key=\$(POWERDNS_API_KEY)
        - --txt-owner-id=$KUBE_ADMIN_USER
        - --domain-filter=intranet.$PRI_DOMAIN
        - --log-level=debug
        - --interval=30s
        env:
        - name: POWERDNS_API_KEY
          valueFrom:
            secretKeyRef:
              name: powerdns-api-key
              key: powerdns-api-key
EOF

kubectl delete namespace $KNS
kubectl create namespace $KNS

API_KEY=$(get_decode_secret_key_val powerdns powerdns-api-key powerdns-api-key)
sealed_secret_gen $SSCERT $KNS powerdns-api-key powerdns-api-key $API_KEY \
    > $MYDIR/powerdns-api-key.sealed.json

kubectl apply -f $MYDIR/powerdns-api-key.sealed.json
kubectl apply -f $MYDIR/external-dns.yaml

# in a little while (don't dig too soon or negative cache ttl kicks in)
# dig ns.intranet.$PRI_DOMAIN
# dig ns
# should both give 10.0.1.2 (or whatever INTRANET_DNS_IP env var is set to be)
