# may wish to reboot -- did dnsmasq come up? kinda don't want to make it the first nameserver
# unless it's gonna be there.

echo -e "nameserver 127.0.0.1\n$(cat /etc/resolv.conf)" | sudo tee /etc/resolv.conf