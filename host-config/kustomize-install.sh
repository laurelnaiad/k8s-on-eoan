########################################################################

# kustomize-install.sh

########################################################################
MYDIR=~/setup-kubernetes/kustomize
mkdir -p $MYDIR
MY_URL=https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.5.4/kustomize_v3.5.4_linux_amd64.tar.gz
wget -qO- $MY_URL | tar -xvz -C $MYDIR
sudo mv $MYDIR/kustomize /usr/bin/kustomize
sudo chmod +x /usr/bin/kustomize
