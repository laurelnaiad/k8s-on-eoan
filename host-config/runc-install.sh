########################################################################

# runc-install.sh

########################################################################
MYDIR=$GOPATH/src/github.com/opencontainers/runc

git clone https://github.com/opencontainers/runc $MYDIR
cd $MYDIR
make BUILDTAGS="selinux seccomp"
sudo cp runc /usr/bin/runc
# I had some other runc in sbin, which is prioritized in $PATH, so
sudo cp runc /usr/sbin/runc
runc --version
sudo runc --version
# => runc version 1.0.0-rc9+dev (or later)...
