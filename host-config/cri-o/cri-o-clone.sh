########################################################################

# cri-o-clone.sh

# This just clones the repo. It's split out from the rest of the config because
# files from this repo are used to configure cni.

########################################################################

MYDIR=$SRC_DIR/cri-o
git clone https://github.com/cri-o/cri-o $MYDIR
