########################################################################

# libpod-podman-skopeo-install.sh

########################################################################

# skopeo
MYDIR=$GOPATH/src/github.com/containers-skopeo
git clone https://github.com/containers/skopeo $MYDIR
cd $MYDIR
make binary-local
make docs
sudo make install
sudo mkdir -p /etc/containers
sudo cp default-policy.json /etc/containers/policy.json

# libpod/podman
MYDIR=$GOPATH/src/github.com/containers-libpod
git clone https://github.com/containers/libpod $MYDIR
cd $MYDIR
make BUILDTAGS="varlink systemd selinux seccomp" # added systemd as compared to instructions
sudo make install PREFIX=/usr


sudo sysctl kernel.unprivileged_userns_clone=1
echo 'kernel.unprivileged_userns_clone=1' | sudo tee -a /etc/sysctl.d/userns.conf


cat <<EOF | sudo tee /etc/containers/libpod.conf
cni_default_network = "cbr0"
runtime = "crun"
EOF


sudo mv /etc/cni/net.d/87-podman-bridge.conflist /etc/cni/net.d/87-podman-bridge.conflist.bak


cat <<EOF | sudo tee /etc/containers/registries.conf
[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF


cat <<EOF | sudo tee /etc/containers/storage.conf
[storage]
  driver = "overlay"
  runroot = "/var/run/containers/storage"
  graphroot = "/var/lib/containers/storage"
  [storage.options]
  mount_program = "/usr/bin/fuse-overlayfs"
EOF


mkdir -p ~/.config/containers
cp /etc/containers/libpod.conf ~/.config/containers/libpod.conf
cat <<EOF | tee ~/.config/containers/storage.conf
[storage]
  driver = "overlay"
  runroot = "/run/user/1000/containers"
  graphroot = "/home/laurelnaiad/.local/share/containers/storage"
  [storage.options]
  mount_program = "/usr/bin/fuse-overlayfs"
EOF
