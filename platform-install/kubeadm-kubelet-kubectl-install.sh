########################################################################

# kubeadm-kubelet-kubectl-install.sh

########################################################################
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
# not sure why I had to install this, guess it got removed by OS install
sudo apt install arptables
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
# install completions
sudo apt-get install bash-completion
echo 'source <(kubectl completion bash)' >>~/.bashrc

sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
