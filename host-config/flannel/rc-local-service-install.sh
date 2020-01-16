########################################################################

# rc-local.sh

# There is a chicken-and-egg scenario where flannel writes /run/flannel/subnet.env,
# but not in time for cri-o to begin creating containers (since flannel runs as one of them).

# This script sets up rc-local service (it is not installed by default in Ubuntu), and
# configures it to write the /run/flannel/subnet.env on every startup.

# Since this runs at SysVStartPriority=99, and since we'll configure the crio service to
# depend on it, and since we'll configure the kubelet to depend on the cri-o service, this
# will cause k8s to be among the very last services started on boot. If that is an issue,
# you can modify SysVStartPriority=99.

# TODO: the script should go with one that runs on shutdown. The shutdown script should
# save a copy of the /run/flannel/subnet.env file, and the startup script should copy that
# file into /run/flannel/subnet.env

########################################################################

# https://www.linuxbabe.com/linux-server/how-to-enable-etcrc-local-with-systemd
cat <<EOF | sudo tee /etc/systemd/system/rc-local.service
[Unit]
 Description=/etc/rc.local Compatibility
 ConditionPathExists=/etc/rc.local

[Service]
 Type=forking
 ExecStart=/etc/rc.local start
 TimeoutSec=0
 StandardOutput=tty
 RemainAfterExit=yes
 SysVStartPriority=99

[Install]
 WantedBy=multi-user.target
EOF

read -r -d '' MY_SCRIPT <<'END'
#!/bin/bash

sudo mkdir -p /run/flannel
cat <<EOF | sudo tee /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF

exit 0
END

echo "$MY_SCRIPT" | sudo tee /etc/rc.local
sudo chmod +x /etc/rc.local

sudo systemctl start rc-local
sudo systemctl enable rc-local
