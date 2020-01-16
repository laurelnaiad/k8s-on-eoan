########################################################################

# fuse-overlayfs-install.sh

# prereq: buildah-install.sh

########################################################################
MYDIR=$SRC_DIR/fuse-overlayfs
git clone https://github.com/containers/fuse-overlayfs $MYDIR
cd $MYDIR
sudo buildah bud -v $PWD:/build/fuse-overlayfs -t fuse-overlayfs -f ./Dockerfile.static.ubuntu .
sudo cp fuse-overlayfs /usr/bin/
