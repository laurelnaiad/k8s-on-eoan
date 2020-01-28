########################################################################

# docker-registry.sh

# if we want to do authenticated/authoerized access:
#   https://github.com/cesanta/docker_auth/blob/master/examples/reference.yml

########################################################################

MYDIR=$WORK_DIR/docker-registry
mkdir -p $MYDIR
rm $MYDIR/docker-registry/values.yaml
helm pull stable/docker-registry -d $MYDIR --untar
until [[ $(stat $MYDIR/docker-registry/values.yaml) ]]
do
  sleep 1
done
sleep 1
cat $MYDIR/docker-registry/values.yaml \
  | yq -y ' .persistence.enabled = true
          | .persistence.size = "20Gi"
          | .persistence.storageClass = "fixed-size"
        ' \
  | tee $MYDIR/docker-registry/values.yaml
helm template $MYDIR/docker-registry \
  | sed -e 's/RELEASE-NAME-//g' \
  | awk '{if( \
      ! /^[\t ]*chart:/ && \
      ! /^[\t ]*heritage:/ && \
      ! /^[\t ]*release:/ \
    ) {print $0}}' \
  | tee $MYDIR/resources.yaml

cat <<EOF > $MYDIR/ingress.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1beta1
metadata:
  name: docker-registry
  namespace: docker-registry
  labels:
    app: docker-registry
  annotations:
    kubernetes.io/ingress.class: nginx-intranet
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    cert-manager.io/cluster-issuer: cert-issuer-prod
spec:
  rules:
  - host: docker-registry.intranet.$PRI_DOMAIN
    http:
      paths:
      - backend:
          serviceName: docker-registry
          servicePort: 5000
  tls:
  - hosts:
    - docker-registry.intranet.$PRI_DOMAIN
    secretName: docker-registry.intranet.$PRI_DOMAIN-tls
EOF

cat <<EOF > $MYDIR/kustomization.yaml
resources:
- resources.yaml
- ingress.yaml
namespace: docker-registry
EOF

kustomize build $MYDIR > $MYDIR/package.yaml

kubectl create namespace docker-registry
kubectl apply -f $MYDIR/package.yaml

# while the docker-registry image is being pulled, we can create a
# partition/persistent volume for the storage...
source ./add-volume.sh
add_volume fixed-size 25Gi
