########################################################################

# 04-k8s-config.sh

########################################################################
./env-vars.sh
./secure-vars.sh

./k8s-config/runtime-classes.sh
./k8s-config/sealed-secrets.sh
./k8s-config/metallb.sh
./k8s-config/nginx-ingress.sh
./k8s-config/cert-manager.sh
./k8s-config/dex.sh
./k8s-config/gangway.sh
