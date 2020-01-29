########################################################################

# 04-k8s-config.sh

########################################################################
source ../env-vars.sh
source ../secure-vars.sh

./k8s-config/runtime-classes.sh
./k8s-config/local-static-provisioner.sh
./k8s-config/sealed-secrets.sh
./k8s-config/cert-manager.sh
./k8s-config/metallb.sh
./k8s-config/nginx-ingress.sh
./k8s-config/postgresql.sh
./k8s-config/powerdns.sh
./k8s-config/external-dns.sh
./k8s-config/docker-registry.sh
./k8s-config/powerdns-push.sh
./k8s-config/dex.sh
./k8s-config/gangway.sh
./k8s-config/authorization-config.sh
./k8s-config/oauth2_proxy.sh
