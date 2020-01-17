########################################################################

# sealed-secrets.sh

########################################################################
MYDIR=$WORK_DIR/sealed-secrets
mkdir -p MYDIR
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.9.6/kubeseal-linux-amd64 \
    -O $MYDIR/kubeseal
sudo install -m 755 $MYDIR/kubeseal /usr/local/bin/kubeseal
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.9.6/controller.yaml
sleep 15
kubeseal --fetch-cert --controller-namespace kube-system > $SSCERT
# retry that last one if it fails the first (few) time(s)
