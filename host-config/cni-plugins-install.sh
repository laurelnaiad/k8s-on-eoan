########################################################################

# cni-plugins-install.sh

# scripts/crio-o/crio-o-clone.sh must be run prior to this script

########################################################################
MYDIR=$SRC_DIR/containernetworking-plugins
$CRIO_DIR=$SRC_DIR/cri-o

git clone https://github.com/containernetworking/plugins $MYDIR
cd $MYDIR
./build_linux.sh
sudo mkdir -p /opt/cni/bin
sudo cp bin/* /opt/cni/bin/
#cd ~/setup-kubernetes/
sudo mkdir -p /etc/cni/net.d
sudo cp $CRIO_DIR/contrib/cni/99-loopback.conf /etc/cni/net.d/
sudo modprobe overlay
sudo modprobe br_netfilter
# Setup required sysctl params, these persist across reboots.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
# the above didn't solve it for me as to persisting across reboots.
# This did, though.
cat <<EOF | sudo tee /etc/modules-load.d/br_netfilter.conf
br_netfilter
EOF
