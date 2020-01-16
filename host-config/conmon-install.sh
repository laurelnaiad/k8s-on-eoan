########################################################################

# conmon-install.sh

########################################################################

# https://github.com/containers/conmon/blob/master/install.md

MYDIR=$SRC_DIR/containers-common
git clone https://github.com/containers/common $MYDIR
cd $MYDIR
sudo make install
sudo make podman
sudo make crio
