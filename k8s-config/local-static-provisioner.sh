########################################################################

# local-static-provisioner.sh

# https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/issues/75

# see also host-config/scratch-volume-mounts.sh, which creates scratch volumes for the provisioner

# see also ./add-volume.sh, for a function that creates a volume for the fixed-size
# storage class.
########################################################################

MYDIR=$WORK_DIR/local-static-provisioner
mkdir -p $MYDIR

git clone --depth=1 https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner $MYDIR/sig-storage-local-static-provisioner
cd $MYDIR/sig-storage-local-static-provisioner
git reset --hard
git pull
# build using podman, not docker
cat Makefile | sed 's/docker /sudo podman /g' > Makefile
make

# SCRATCH_CLASS is configured out of what is already present in values.yaml
# FIXED_SIZE_CLASS is added to the classes list after the scratch class
read -r -d '' FIXED_CLASS_CONFIG <<EOF
- name: $FIXED_SIZE_CLASS
  hostDir: $PERSISTENT_VOLUME_DISCO_DIR/$FIXED_SIZE_CLASS
  volumeMode: Filesystem
  fsType: ext4
  storageClass: true
EOF
SCRATCH_DIR_ESC=$(echo $PERSISTENT_VOLUME_DISCO_DIR/$SCRATCH_CLASS | sed 's/\//\\\//g')
cat $MYDIR/sig-storage-local-static-provisioner/helm/provisioner/values.yaml \
  | sed 's/namespace:.*/namespace: local-static-provisioner/' \
  | sed 's/podSecurityPolicy:.*/podSecurityPolicy: true/' \
  | sed "s/name: fast-disks.*/name: $SCRATCH_CLASS/" \
  | sed "s/hostDir:.*/hostDir: $SCRATCH_DIR_ESC/" \
  | sed 's/# storageClass:$/storageClass:/' \
  | sed 's/# reclaimPolicy:/reclaimPolicy:/' \
  | sed 's/# isDefaultClass:/isDefaultClass:/' \
  | awk -v FIXED_CLASS_CONFIG="$FIXED_CLASS_CONFIG" \
      '{if (/isDefaultClass/) {print $0 "\n" FIXED_CLASS_CONFIG} else {print $0}}' \
  > $MYDIR/values.yaml

helm template -f $MYDIR/values.yaml $MYDIR/sig-storage-local-static-provisioner/helm/provisioner \
  | sed -e 's/RELEASE-NAME-//g' \
  | awk '{if( \
      ! /^[\t ]*chart:/ && \
      ! /^[\t ]*heritage:/ && \
      ! /^[\t ]*release:/ \
    ) {print $0}}' \
  > $MYDIR/resources.yaml

cat <<EOF > $MYDIR/kustomization.yaml
resources:
- resources.yaml
namespace: local-static-provisioner
patchesJson6902:
- target:
    group: apps
    version: v1
    namespace: local-static-provisioner
    name: local-volume-provisioner
    kind: DaemonSet
  patch: |-
    - op: add
      path: /spec/template/spec/containers/0/imagePullPolicy
      value: IfNotPresent
    - op: replace
      path: /spec/template/spec/containers/0/image
      value: "quay.io/external_storage/local-volume-provisioner-amd64:latest"
    - op: replace
      path: /spec/template/spec/containers/0/env/2/value
      value: "quay.io/external_storage/local-volume-provisioner-amd64:latest"
EOF

kubectl create namespace local-static-provisioner
kustomize build $MYDIR | kubectl apply -f -
