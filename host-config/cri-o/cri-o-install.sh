########################################################################

# cri-o-install.sh

# prereqs inc. cri-o-clone.sh, which clones the repo
########################################################################
MYDIR=$SRC_DIR/cri-o
cd $MYDIR
sudo sysctl --system
sudo rm /etc/crio/crio.conf
sudo make clean
make BUILDTAGS='seccomp apparmor'
sudo make install
sudo make install.config

# configure crio
# a) use crun by default, instead of runc
# b) modify cgroup_manager as per setup.md
# c) fix path to hooks.d
# set storage_driveer to fuse-overlayfs

read -r -d '' MY_CONFIG << EOM
[crio.runtime.runtimes.crun]
runtime_path = "/usr/local/bin/crun"
runtime_type = "oci"
runtime_root = "/var/run/containers/storage"

EOM
cat /etc/crio/crio.conf \
  | awk -v CONFIG="$MY_CONFIG" '{if(/^\[crio.runtime.runtimes.runc\]/) {print CONFIG "\n\n" $0} else {print $0} }' \
  | awk '{if(/^default_runtime = "runc"/) {print "# " $0 "\ndefault_runtime = \"crun\""} else {print $0} }' \
  | awk '{if(/^cgroup_manager[ =]/) {print "# (repl. as per setup.md) " $0 "\n" $1 " = \"systemd\""} else {print $0} }' \
  | awk '{if(/\/usr\/share\/containers\/oci\/hooks\.d/) {print "  \"/usr/local/share/containers/oci/hooks.d\","} else {print $0}}' \
  | awk '{if(/^#storage_driver/) {print "storage_driver = \"overlay\"\nstorage_option = [ \"overlay.mount_program=/usr/bin/fuse-overlayfs\", \"overlay.mountopt=nodev\" ]"} else {print $0}}' \
  | sudo tee /etc/crio/crio.conf
sudo make install.systemd
sudo systemctl daemon-reload
sudo systemctl enable crio
sudo systemctl restart crio
