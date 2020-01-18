########################################################################

# helm-install.sh

########################################################################
MYDIR=$WORK_DIR/helm
mkdir -p $MYDIR
wget -P $MYDIR https://get.helm.sh/helm-v3.0.2-linux-amd64.tar.gz
tar -C $MYDIR -xzf $MYDIR/helm-v3.0.2-linux-amd64.tar.gz
sudo cp $MYDIR/linux-amd64/helm /usr/bin/helm
rm -rf $MYDIR/linux-amd64
rm $MYDIR/helm-v3.0.2-linux-amd64.tar.gz

helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update
