########################################################################

# kubeadm-kubelet-kubectl-config.sh

########################################################################
sudo mkdir -p /lib/systemd/system/kubelet.service.d

cat <<'EOF' | sudo tee /lib/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/
Wants=crio.socket

[Service]
ExecStart=/bin/kubelet
#########################
# The following (Slice) is important.... otherwise we get slices out of
# sorts. Need to contruct a real cgroup hierarcy (TBD).
########################
Slice=system.slice
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# https://stackoverflow.com/posts/1252191/revisions
read -r -d '' MY_KUBELET_ARGS <<'EOF'
--feature-gates='AllAlpha=false,RunAsGroup=true'
--network-plugin=cni
--container-runtime=remote
--cgroup-driver=systemd
--container-runtime-endpoint='unix:///var/run/crio/crio.sock'
--runtime-request-timeout=20m
--resolv-conf=/etc/resolv.public.conf
--kubelet-cgroups=/system.slice
--runtime-cgroups=/system.slice
EOF

MY_KUBELET_ARGS=$(echo "$MY_KUBELET_ARGS" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g')
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="$MY_KUBELET_ARGS"
EOF

sudo systemctl daemon-reload
sudo systemctl enable kubelet.service

cat <<EOF | tee $WORK_DIR/kubeadm-config.yml
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
# mode: ipvs
localAPIEndpoint:
  advertiseAddress: $ADVERTISE_ADDR
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v1.17.0
clusterName: $CLUSTER_NAME
networking:
  podSubnet: 10.244.0.0/16
scheduler:
  extraArgs:
    authentication-kubeconfig: /etc/kubernetes/scheduler.conf
    authorization-kubeconfig: /etc/kubernetes/scheduler.conf
apiServer:
  extraArgs:
    oidc-issuer-url: $DEX_ISSUER_URL
    oidc-client-id: kubernetes
    oidc-username-claim: email
    oidc-groups-claim: groups
EOF
# If we don't probe the br_netfilter then kubeadm init may fail
# ("/proc/sys/net/bridge/bridge-nf-call-iptables does not exist").
# https://github.com/kubernetes/kubeadm/issues/1062
sudo modprobe br_netfilter
echo '1' | sudo tee /proc/sys/net/ipv4/ip_forward

sudo kubeadm init --config=$WORK_DIR/kubeadm-config.yml
rm -rf ~/.kube
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
