########################################################################

# flannel-install.sh

########################################################################

# as per https://github.com/coreos/flannel/blob/master/Documentation/kubernetes.md
kubectl apply -f  https://raw.githubusercontent.com/coreos/flannel/3f7d3e6c24f641e7ff557ebcea1136fdf4b1b6a1/Documentation/kube-flannel.yml

sleep 10

# # https://blog.heptio.com/properly-resetting-your-kubeadm-bootstrapped-cluster-nodes-heptioprotip-473bd0b824aa
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
