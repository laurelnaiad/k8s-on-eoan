########################################################################

# metallb.sh

# https://metallb.universe.tf/installation/
# https://metallb.universe.tf/configuration/

########################################################################
MYDIR=$WORK_DIR
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
cat <<EOF | tee $MYDIR/metallb-config.yml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: load-balancer
      protocol: layer2
      addresses:
      - $LB_IP-$LB_IP
    - name: intranet-dns
      protocol: layer2
      addresses:
      - $INTRANET_DNS_IP-$INTRANET_DNS_IP
    - name: public-ip
      protocol: layer2
      addresses:
      - $PUBLIC_IP_RANGE
    - name: default
      protocol: layer2
      addresses:
      - $PRIVATE_IP_RANGE
EOF
kubectl apply -f $MYDIR/metallb-config.yml
kubectl rollout restart -n metallb-system deploy/controller
