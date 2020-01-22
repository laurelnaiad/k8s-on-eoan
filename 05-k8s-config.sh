########################################################################

# 04-k8s-config.sh

########################################################################
source ../env-vars.sh
source ../secure-vars.sh

./k8s-config/runtime-classes.sh
./k8s-config/local-static-provisioner.sh
./k8s-config/etcd-operator.sh
./k8s-config/sealed-secrets.sh
./k8s-config/metallb.sh
./k8s-config/nginx-ingress.sh
./k8s-config/intranet-dns.sh
./k8s-config/cert-manager.sh
./k8s-config/dex.sh
./k8s-config/gangway.sh
./k8s-config/authorization-config.sh
