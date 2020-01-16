########################################################################

# crictl-install.sh

########################################################################
MYDIR=$SRC_DIR/cri-tools
git clone https://github.com/kubernetes-sigs/cri-tools $MYDIR
cd $MYDIR
make all
sudo make install
echo "runtime-endpoint: unix:///var/run/crio/crio.sock" | sudo tee /etc/crictl.yaml
