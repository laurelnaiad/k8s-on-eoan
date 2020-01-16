########################################################################

# crun-install.sh

########################################################################
MYDIR=$SRC_DIR/containers-crun

git clone https://github.com/containers/crun $MYDIR
cd $MYDIR
./autogen.sh && ./configure
make
sudo make install
