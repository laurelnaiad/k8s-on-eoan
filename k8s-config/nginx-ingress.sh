########################################################################

# nginx-ingress.sh

# https://kubernetes.github.io/ingress-nginx/deploy/

########################################################################
MYDIR=$WORK_DIR
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.2/deploy/static/mandatory.yaml
# expose an ingress
wget -O $MYDIR/ingress-config.yml https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.26.2/deploy/static/provider/cloud-generic.yaml
# give the ingress an address (specifically, the single address in the pool
# named "load-balancer") to the ingress controller.
cat $MYDIR/ingress-config.yml \
  | awk '{if(/^metadata/) {print $0 "\n  annotations:\n    metallb.universe.tf/address-pool: load-balancer"} else {print $0}}' \
  | tee $MYDIR/ingress-config.yml
kubectl apply -f $MYDIR/ingress-config.yml
