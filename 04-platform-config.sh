########################################################################

# 03-platform-config.sh

########################################################################
source ../env-vars.sh
source ../secure-vars.sh

./platform-install/kubeadm-kubelet-kubectl-config.sh
./platform-install/pod-security-policy.sh
./platform-install/flannel-install.sh
