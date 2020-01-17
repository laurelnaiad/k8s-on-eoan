########################################################################

# sealed-secrets.sh

########################################################################
MYDIR=$WORK_DIR/sealed-secrets
mkdir -p MYDIR
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.9.6/kubeseal-linux-amd64 \
    -O $MYDIR/kubeseal
sudo install -m 755 $MYDIR/kubeseal /usr/local/bin/kubeseal
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.9.6/controller.yaml
until kubeseal --fetch-cert --controller-namespace kube-system > $SSCERT
do
  echo "pausing to let sealed-secrets generate controller certificate"
  sleep 2
done
