########################################################################

# buildah-install.sh

########################################################################
MYDIR=$GOPATH/src/github.com/containers/buildah
git clone https://github.com/containers/buildah.git $MYDIR
cd $MYDIR
make all SECURITYTAGS="apparmor seccomp"
sudo make install
