########################################################################

# intranet-dns.sh

# https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/coredns.md
# in order to support intranet dns, installs stack consisting of:
# 1. etcd-cluster and etcd-cluster-client
# 2. coredns
# 3. external-dns

########################################################################
MYDIR=$WORK_DIR/intranet-dns
mkdir -p $MYDIR/etcd-operator

kubectl create namespace intranet-dns

# the role is the same as what is already configured for the operator as a clusterrole.
# just grab that manifest and tweak it.
ROLE_MANIFEST=$(kubectl get clusterrole etcd-operator -o yaml)
echo "$ROLE_MANIFEST" \
  | yq -y  '.kind = "Role"' \
  | yq -y  '.metadata = { "name": "etcd-operator" }' \
  > $MYDIR/etcd-operator/etcd-role.yaml

cat <<EOF > $MYDIR/etcd-operator/etcd-role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app: etcd-operator
  name: etcd-operator
  namespace: intranet-dns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: etcd-operator
subjects:
- kind: ServiceAccount
  name: etcd-operator
  namespace: etcd-operator
EOF

cat <<EOF > $MYDIR/etcd-operator/etcd-cluster.yaml
apiVersion: "etcd.database.coreos.com/v1beta2"
kind: "EtcdCluster"
metadata:
  name: etcd-cluster
  namespace: intranet-dns
  annotations:
    etcd.database.coreos.com/scope: clusterwide
spec:
  size: 1
  version: "3.4.0"
  pod:
    restartPolicy: Always
    persistentVolumeClaimSpec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 50Mi
EOF

# Expose etcd client at a fixed/known ip, rather than relying on the service
# fqdn. We do this because it's the kube-dns server itself which needs to
# contact it.
cat <<EOF > $MYDIR/etcd-operator/etcd-client-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: etcd-client-fixed
  namespace: intranet-dns
spec:
  clusterIP: $INTRANET_DNS_ETCD_FIXED_IP
  ports:
  - name: client
    port: 2379
    protocol: TCP
    targetPort: 2379
  selector:
    etcd_cluster: etcd-cluster
  type: ClusterIP
EOF


cat <<EOF > $MYDIR/etcd-operator/kustomization.yaml
resources:
- etcd-role.yaml
- etcd-role-binding.yaml
- etcd-cluster.yaml
- etcd-client-service.yaml
namespace: intranet-dns
EOF

# get status of the cluster
# kubectl exec -i -n intranet-dns etcd-cluster...... -- /bin/sh -ec 'echo $(ETCDCTL_API=3 etcdctl endpoint status)'

kustomize build $MYDIR/etcd-operator > $MYDIR/etcd-operator/package.yaml
kubectl apply -f $MYDIR/etcd-operator/package.yaml


#############################################################################
# coredns
#############################################################################

# all we need to do is update the existing coredns deployment (in the form
# of its configmap)

MY_MANIFEST=$(kubectl get configmaps -n kube-system coredns -o yaml)
if ! [[ $MY_MANIFEST =~ "etcd intranet" ]]
then
read -r -d '' MY_ZONE <<EOF
etcd intranet.$PRI_DOMAIN {
  stubzones
  path /skydns
  endpoint http://$INTRANET_DNS_ETCD_FIXED_IP:2379
}
EOF
# prepend 8 spaces to each line
MY_ZONE="$(echo "$MY_ZONE" | sed -e 's/^/        /')"
echo "$MY_MANIFEST" \
  | awk -v MY_ZONE="$MY_ZONE" '{if (/^\s*ready\s*$/) {print $0 "\n" MY_ZONE} else {print $0}}' \
  > $MYDIR/coredns-configmap.yaml
kubectl apply -f $MYDIR/coredns-configmap.yaml
kubectl rollout restart deployment -n kube-system coredns
fi

# expose kube-dns at an ip external to the k8s cluster, since it's now serving
# names for things that will actually be accessible outside the cluster.
# (If resources were no object, probably wouldn't be piggybacking on the
# kube's coredns pods).
cat <<EOF > $MYDIR/dns-intranet-ip.yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    metallb.universe.tf/address-pool: intranet-dns
    external-dns.alpha.kubernetes.io/hostname: ns.intranet.$PRI_DOMAIN
  labels:
    app: intranet-dns
  name: dns-intranet-ip
  namespace: kube-system
spec:
  ports:
  - name: dns
    port: 53
    protocol: UDP
    targetPort: 53
  selector:
    k8s-app: kube-dns
  sessionAffinity: None
  type: LoadBalancer
EOF
kubectl apply -f $MYDIR/dns-intranet-ip.yaml

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
  namespace: intranet-dns
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: intranet-dns
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: intranet-dns
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
        - --provider=coredns
        - --log-level=debug # debug only
        env:
        - name: ETCD_URLS
          value: http://$INTRANET_DNS_ETCD_FIXED_IP:2379
        - name: EXTERNAL_DNS_DOMAIN_FILTER
          value: intranet.$PRI_DOMAIN
EOF
kubectl apply -f $MYDIR/external-dns.yaml

# within a second or two..
# dig ns.intranet.$PRI_DOMAIN
# dig ns
# should both give 10.0.1.2 (or whatever INTRANET_DNS_IP env var is set to be)
