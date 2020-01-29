########################################################################################################

# metric-server.sh

########################################################################################################

MYDIR=$WORK_DIR/metrics-server
mkdir -p $MYDIR

git clone https://github.com/kubernetes-sigs/metrics-server $MYDIR/kubernetes-sigs-metrics-server --depth 1
cat <<EOF > $MYDIR/kustomization.yaml
resources:
- kubernetes-sigs-metrics-server/deploy/1.8+/aggregated-metrics-reader.yaml
- kubernetes-sigs-metrics-server/deploy/1.8+/auth-delegator.yaml
- kubernetes-sigs-metrics-server/deploy/1.8+/auth-reader.yaml
- kubernetes-sigs-metrics-server/deploy/1.8+/metrics-apiservice.yaml
- kubernetes-sigs-metrics-server/deploy/1.8+/metrics-server-deployment.yaml
- kubernetes-sigs-metrics-server/deploy/1.8+/metrics-server-service.yaml
- kubernetes-sigs-metrics-server/deploy/1.8+/resource-reader.yaml
patchesJson6902:
- target:
    group: apps
    version: v1
    namespace: kube-system
    name: metrics-server
    kind: Deployment
  # https://github.com/kubernetes-sigs/metrics-server/issues/247
  patch: |-
    - op: replace
      path: /spec/template/spec/containers/0/args
      value:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP
EOF
kustomize build $MYDIR > $MYDIR/package.yaml

kubectl apply -f $MYDIR/package.yaml
