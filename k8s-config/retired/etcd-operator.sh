########################################################################

# etcd-operator.sh

########################################################################

#############################################################################
# build etcd-operator
#############################################################################
# OPERATOR_IMAGE=docker.pkg.github.com/cbws/etcd-operator/operator:latest
# if ! [[ $(sudo podman image inspect $OPERATOR_IMAGE) ]]
# then
# mkdir -p $GOPATH/src/github.com/coreos
# git clone https://github.com/laurelnaiad/etcd-operator $GOPATH/src/github.com/coreos/etcd-operator
# cd $GOPATH/src/github.com/coreos/etcd-operator
# git checkout more_configs_exposed
# git pull
# go get -v -t -d ./...
# ./hack/build/operator/build
# ./hack/build/backup-operator/build
# ./hack/build/restore-operator/build
# kubectl delete namespace etcd-operator
# sudo podman rmi $OPERATOR_IMAGE
# sudo podman build -t $OPERATOR_IMAGE -f hack/build/Dockerfile .
# fi

#############################################################################
# configure etcd-operator
#############################################################################

MYDIR=$WORK_DIR/etcd-operator
mkdir -p $MYDIR

OPERATOR_IMAGE=cbws/etcd-operator:v0.10.0
OP_IMG_ESC=$(echo "$OPERATOR_IMAGE" | sed 's/\//\\\//g')
helm template stable/etcd-operator \
  | tac | sed "1,3d" | tac \
  | sed -e "s/image: .*$/image: $OP_IMG_ESC/" \
  | sed -e 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/' \
  | sed -e 's/RELEASE-NAME-//g' \
  | sed -e 's/etcd-operator-//g' \
  | awk '{if( \
      ! /^[\t ]*chart:/ && \
      ! /^[\t ]*heritage:/ && \
      ! /^[\t ]*release:/ \
    ) {print $0}}' \
  > $MYDIR/resources.yaml

cat <<EOF > $MYDIR/kustomization.yaml
resources:
- resources.yaml
namespace: etcd-operator
patchesJson6902:
- target:
    group: apps
    version: v1
    namespace: etcd-operator
    name: etcd-operator
    kind: Deployment
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/command
      value:
      - etcd-operator
      - "-cluster-wide"
      # - "-log-level=5"
EOF

kustomize build $MYDIR > $MYDIR/package.yaml

kubectl create namespace etcd-operator
kubectl apply -f $MYDIR/package.yaml
