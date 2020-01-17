########################################################################

# 03-platform-config.sh

########################################################################
./env-vars.sh
./secure-vars.sh

./platform-install/kubeadm-kubelet-kubectl-config.sh
./platform-install/flannel-install.sh
