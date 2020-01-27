########################################################################

# dnsmasq-config.sh

# Ubuntu has a few layers of helpers in the way of running dnsmasq as we wish.
# This script wipes out those "helpers" and installs dnsmasq. The upstream name
# servers are hardcoded to google's. Two resolv.confs are produced, one for
# consultation by this host (/etc/resolv.conf), the other for consultation by
# the kubernetes name server (/etc/resolv.public.conf). This is to eliminate
# the potential for a forwarding loop. With this config, other machines
# on the intranet can use this host as the forwarding nameserver.

########################################################################

# chop out ubuntu resolv.conf madness
# if we let coredns look at /etc/resolv.conf and it points to a loopback
# we make a loop.
echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
cat /etc/NetworkManager/NetworkManager.conf \
    | awk '{if(/^\[main\]/) {print $0 "\ndns=none"} else {print $0} }' \
    | sudo tee /etc/NetworkManager/NetworkManager.conf
sudo systemctl restart NetworkManager
sudo apt-get remove resolvconf
sudo rm /etc/resolv.conf
printf "nameserver 8.8.8.8\nnameserver 8.8.4.4\n" | sudo tee /etc/resolv.conf
# /etc/resolv.public.conf is what kubelet will use. Separating them so that
# we don't create a loop.
sudo cp /etc/resolv.conf /etc/resolv.public.conf

sudo apt-get install dnsmasq
# I'm suspicious of this under ubuntu 19.10
# sudo sed -i 's/After=network.target/After=NetworkManager-wait-online.service/' \
#   /lib/systemd/system/dnsmasq.service
MY_ADDRESSES="listen-address=127.0.0.1\nlisten-address=$(hostname -I | sed 's/ .*//')"
read -r -d '' MY_BLOCK <<EOF
$MY_ADDRESSES

server=/cluster.local/10.96.0.10
server=/intranet.$PRI_DOMAIN/$INTRANET_DNS_IP
server=8.8.8.8
server=8.8.4.4

no-resolv
domain-needed
bogus-priv
strict-order
EOF
echo -e "$MY_BLOCK\n\n\n\n$(cat /etc/dnsmasq.conf)" | sudo tee /etc/dnsmasq.conf
sudo systemctl restart dnsmasq
sudo systemctl enable dnsmasq

# There remains one step, which is to make the new dnsmasq server the primary
# name server for the host, but that will be done after a reboot and a check
# to make sure that dnsmasq is working. We don't want to make it the primary
# nameserver if it isn't starting up properly.
