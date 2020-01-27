########################################################################

# mariadb.sh

########################################################################

MYDIR=$WORK_DIR/mariadb
MYCHARTDIR=$MYDIR/mariadb
KNS=mariadb
MYSQL_PASS=$(openssl rand -base64 24 | sed 's/\//-/g')
MY_SECRET=mariadb
MY_SECRET_KEY=mariadb-root-password
MY_BASE_IMG=docker.io/bitnami/mariadb:10.3.21

mkdir -p $MYDIR

# enabling name-resolve in mariadb container is way harder than it should be,
# starting w/the fact that skip-name-resolve in a conf file cannot be undone
# at the command line, not from a subsequent conf file entry...
# solution is to tweak the image...

# ... but unfortunately, buildah commit bombs under sudo, not sure why, so I have to
# move the image around quite a bit more than i'd like. Be easier if private
# registry was already configured, but configuring it properly requires
# dns, and dns needs mariadb, so..

if ! [[ $(sudo podman inspect containers-storage:$MY_BASE_IMG-NAME-RESOLVE) ]]
then
  podman pull $MY_BASE_IMG-debian-9-r26
  MYCTR=$(buildah from containers-storage:$MY_BASE_IMG-debian-9-r26)
  buildah run --user root:root $MYCTR -- sed -i 's/skip-name-resolve/enable-name-resolve/' /libmysql.sh
  buildah commit $MYCTR containers-storage:$MY_BASE_IMG-NAME-RESOLVE

  mkdir -p $MYDIR/image_temp
  skopeo copy containers-storage:$MY_BASE_IMG-NAME-RESOLVE dir:$MYDIR/image_temp
  sudo skopeo copy dir:$MYDIR/image_temp containers-storage:$MY_BASE_IMG-NAME-RESOLVE
  rm -rf $MYDIR/image_temp
  buildah rm $MYCTR
  podman rmi containers-storage:$MY_BASE_IMG-NAME-RESOLVE
  # podman rmi containers-storage:$MY_BASE_IMG-debian-9-r26
fi

rm $MYCHARTDIR/values.yaml

helm pull stable/mariadb -d $MYDIR --untar

until [[ $(stat $MYCHARTDIR/values.yaml) ]]
do
  sleep 1
done
sleep 1

cat $MYCHARTDIR/values.yaml \
  | yq -y --arg CMDS "$MY_CMDS" ' .master.persistence.enabled = true
          | .master.persistence.size = "18Gi"
          | .master.persistence.storageClass = "fixed-size"
          | .serviceAccount.create = true
          | .rbac.create = true
          | .replication.enabled = false
        ' \
  | tee $MYCHARTDIR/values.yaml

sleep 2

helm template $MYCHARTDIR  \
  | sed -e 's/RELEASE-NAME-//g' \
  | awk '{if( \
      ! /^[\t ]*chart:/ && \
      ! /^[\t ]*heritage:/ && \
      ! /^[\t ]*release:/ \
    ) {print $0}}' \
  | tee $MYDIR/resources.yaml

# {
#   "name": "MARIADB_EXTRA_FLAGS",
#   "value": "--enable-name-resolve"
# },

sleep 2

# the mariadb-test pod just fails because it tries to connect before the server pod is ready,
# so get rid of it. Also, we're generating a sealed secret password, so remove that, too.
cat $MYDIR/resources.yaml | yq -y --arg IMG "$MY_BASE_IMG-NAME-RESOLVE" '.
  | select(.metadata.name | test("mariadb-test") | not)
  | select(.kind | test("Secret") | not)
  | if .kind | test("StatefulSet") then
    .spec.template.spec.containers[0].image = $IMG
  | .spec.template.spec.containers[0].env = [
    {
      "name": "MARIADB_EXTRA_FLAGS",
      "value": "--enable-name-resolve=TRUE"
    },
    {
      "name": "NAMI_LOG_LEVEL",
      "value": "trace8"
    },
    {
      "name": "MARIADB_ROOT_PASSWORD",
      "valueFrom": { "secretKeyRef": {
        "name": "mariadb",
        "key": "mariadb-root-password"
    } } }
  ]
  else
    .
  end
' | tee $MYDIR/resources.yaml


cat <<EOF > $MYDIR/kustomization.yaml
resources:
- resources.yaml
namespace: $KNS
EOF

kustomize build $MYDIR > $MYDIR/package.yaml

kubectl create namespace $KNS


kubectl create secret generic -n $KNS $MY_SECRET \
      --dry-run \
      --from-literal=$MY_SECRET_KEY=$MYSQL_PASS \
      -o json \
  | kubeseal --cert $SSCERT \
  >$MYDIR/$MY_SECRET.sealed.json
kubectl apply -f $MYDIR/$MY_SECRET.sealed.json

kubectl apply -f $MYDIR/package.yaml

sleep 2
until [ $(kubectl get pods --namespace mariadb \
    | awk '{if(/mariadb-/) {print $2}}' \
    | awk -F/ '{print $1}') -gt 0 ]
do
  echo "`date +%r` -- waiting for mariadb to be ready"
  sleep 2
done

read -r -d '' MY_CMDS <<EOF
DROP USER root@'%';
GRANT ALL privileges ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '${MYSQL_PASS}' WITH GRANT OPTION;
GRANT ALL privileges ON *.* TO 'root'@'localhost' IDENTIFIED BY '${MYSQL_PASS}' WITH GRANT OPTION;
GRANT ALL privileges ON *.* TO 'root'@'::1' IDENTIFIED BY '${MYSQL_PASS}' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

MY_POD=$(kubectl get pods -n mariadb | awk '{if ($1 ~ /mariadb-[[:digit:]]/) {print $1}}')

kubectl exec -n mariadb $MY_POD -- /bin/sh -c "echo \"$MY_CMDS\" | mysql -u root -p${MYSQL_PASS}"
