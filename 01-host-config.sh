########################################################################

# 01-host-config.sh

########################################################################
source ../env-vars.sh
source ../secure-vars.sh

# https://blog.heptio.com/properly-resetting-your-kubeadm-bootstrapped-cluster-nodes-heptioprotip-473bd0b824aa
sudo timedatectl set-timezone Etc/UTC

./host-config/setup-dirs.sh
./host-config/flannel/rc-local-service-install.sh
./host-config/apt-installs.sh
./host-config/git-config.sh
./dnsmasq-install/dnsmasq-config.sh
./host-config/golang-install.sh
./host-config/conmon-install.sh
./host-config/crun-install.sh
./host-config/runc-install.sh
./host-config/crio-o/crio-o-clone.sh
./host-config/cni-plugins-install.sh
./host-config/buildah-install.sh
./host-config/fuse-overlayfs-install.sh
./host-config/libpod-podman-skopeo/varlink-install.sh
./host-config/libpod-podman-skopeo/libpod-podman-skopeo-install.sh
./host-config/libpod-podman-skopeo/podman-socket-service.sh
./host-config/libpod-podman-skopeo/alias-docker.sh
./host-config/crio-o/crio-o-install.sh
./host-config/kustomize-install.sh
./host-config/helm-install.sh
./host-config/yq.sh
