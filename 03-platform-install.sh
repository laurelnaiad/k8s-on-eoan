########################################################################

# 03-platform-install.sh

########################################################################
./env-vars.sh
./secure-vars.sh

./platform-install/kubeadm-kubelet-kubectl-install.sh
./platform-install/flannel-install.sh
